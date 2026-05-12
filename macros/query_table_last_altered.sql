{% macro query_table_last_altered(resources) %}
    {{ return(adapter.dispatch("query_table_last_altered", "upstream_prod")(resources)) }}
{% endmacro %}

{% macro default__query_table_last_altered(resources) %}

    {% set warning_msg %}
upstream_prod_prefer_recent is set to true but this feature is incompatible with {{ target.type }} databases. Unsetting the variable may improve project performance.
    {% endset %}
    {% do exceptions.warn(warning_msg) %}

    {{ return(None) }}

{% endmacro %}


{% macro snowflake__query_table_last_altered(resources) %}
    -- Query assumes database objects don't have case-sensitive names
    {% call statement("last_modified", fetch_result=True) %}
        {% for db, db_resources in resources.items() %}
            {# Flatten schemas within the database #}
            {% set flat_db_resources = [] %}
            {% for schema, schema_resources in db_resources.items() %}
                {% for res in schema_resources %}
                    {% do flat_db_resources.append({"resource": res.resource, "env": res.env, "schema": schema, "name": res.name}) %}
                {% endfor %}
            {% endfor %}

            select
                rm.resource,
                rm.env,
                t.table_catalog as database,
                t.table_schema as schema,
                t.table_name as name,
                t.last_altered
            from {{ db }}.information_schema.tables t
            inner join (
                select column1 as resource, column2 as env, column3 as match_schema, column4 as match_name
                from values
                    {% for res in flat_db_resources %}
                        ('{{ res.resource }}', '{{ res.env }}', '{{ res.schema }}', '{{ res.name }}')
                        {%- if not loop.last %},{% endif %}
                    {% endfor %}
            ) rm
                on upper(t.table_schema) = upper(rm.match_schema)
                and upper(t.table_name) = upper(rm.match_name)

            {% if not loop.last %} union all {% endif %}
        {% endfor %}
    {% endcall %}

    {{ return(load_result("last_modified")) }}

{% endmacro %}


{% macro databricks__query_table_last_altered(resources) %}
    {# Flatten resources from all databases and schemas into a single list #}
    {% set all_resources = [] %}
    {% for db, db_resources in resources.items() %}
        {% for schema, schema_resources in db_resources.items() %}
            {% for res in schema_resources %}
                {% do all_resources.append({"resource": res.resource, "env": res.env, "database": db, "schema": schema, "name": res.name}) %}
            {% endfor %}
        {% endfor %}
    {% endfor %}

    -- Query assumes database objects don't have case-sensitive names
    {% call statement("last_modified", fetch_result=True) %}
        select
            rm.resource,
            rm.env,
            t.table_catalog as database,
            t.table_schema as schema,
            t.table_name as name,
            t.last_altered
        from system.information_schema.tables t
        inner join (
            select col1 as resource, col2 as env, col3 as match_database, col4 as match_schema, col5 as match_name
            from values
                {% for res in all_resources %}
                    ('{{ res.resource }}', '{{ res.env }}', '{{ res.database|lower }}', '{{ res.schema|lower }}', '{{ res.name|lower }}')
                    {%- if not loop.last %},{% endif %}
                {% endfor %}
        ) rm
            on t.table_catalog = rm.match_database
            and t.table_schema = rm.match_schema
            and t.table_name = rm.match_name
    {% endcall %}

    {{ return(load_result("last_modified")) }}

{% endmacro %}


{% macro bigquery__query_table_last_altered(resources) %}
    {# BigQuery requires querying per-schema (no database-wide INFORMATION_SCHEMA.TABLES),
       and errors when the queried dataset does not exist. Probe INFORMATION_SCHEMA.SCHEMATA
       first per database, then build the union only over (db, schema) pairs that exist. #}
    {% set existing_schemas = {} %}
    {% for db in resources.keys() %}
        {% set schemata_query %}
            select schema_name from `{{ db }}`.INFORMATION_SCHEMA.SCHEMATA
        {% endset %}
        {% set schemata_result = run_query(schemata_query) %}
        {% set names = [] %}
        {% if schemata_result is not none %}
            {% for row in schemata_result %}
                {% do names.append(row[0] | lower) %}
            {% endfor %}
        {% endif %}
        {% do existing_schemas.update({db: names}) %}
    {% endfor %}

    {% set flat_schemas = [] %}
    {% for db, db_resources in resources.items() %}
        {% for schema, schema_resources in db_resources.items() %}
            {% if schema | lower in existing_schemas.get(db, []) %}
                {% do flat_schemas.append({
                    "database": db,
                    "schema": schema,
                    "resources": schema_resources
                }) %}
            {% endif %}
        {% endfor %}
    {% endfor %}

    {# If none of the parent envs have a dataset yet (e.g. first run before any seed/snapshot
       has been built in dev), there are no timestamps to look up. #}
    {% if flat_schemas | length == 0 %}
        {{ return(None) }}
    {% endif %}

    {% call statement("last_modified", fetch_result=True) %}
        {% for schema_group in flat_schemas %}
            select
                rm.resource,
                rm.env,
                inf_sch.table_catalog as database,
                inf_sch.table_schema as schema,
                inf_sch.table_name as name,
                coalesce(
                    timestamp_millis(meta.last_modified_time),
                    inf_sch.creation_time
                ) as last_altered
            from `{{ schema_group.database }}.{{ schema_group.schema }}.INFORMATION_SCHEMA.TABLES` inf_sch
            left join `{{ schema_group.database }}.{{ schema_group.schema }}.__TABLES__` meta
                on inf_sch.table_catalog = meta.project_id
                and inf_sch.table_schema = meta.dataset_id
                and inf_sch.table_name = meta.table_id
            inner join (
                -- BigQuery doesn't support aliased columns in VALUES without SELECT
                {% for res in schema_group.resources %}
                    select '{{ res.resource }}' as resource, '{{ res.env }}' as env, '{{ schema_group.database|lower }}' as match_database, '{{ schema_group.schema|lower }}' as match_schema, '{{ res.name|lower }}' as match_name
                    {%- if not loop.last %} union all {% endif %}
                {% endfor %}
            ) rm
                on inf_sch.table_catalog = rm.match_database
                and inf_sch.table_schema = rm.match_schema
                and inf_sch.table_name = rm.match_name

            {% if not loop.last %} union all {% endif %}
        {% endfor %}
    {% endcall %}

    {{ return(load_result("last_modified")) }}

{% endmacro %}
