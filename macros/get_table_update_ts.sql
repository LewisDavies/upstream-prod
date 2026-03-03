{% macro get_table_update_ts(resources) %}
    {{ return(adapter.dispatch("get_table_update_ts", "upstream_prod")(resources)) }}
{% endmacro %}

{% macro default__get_table_update_ts(resources) %}

    {% set warning_msg %}
upstream_prod_prefer_recent is set to true but this feature is incompatible with {{ target.type }} databases. Unsetting the variable may improve project performance.
    {% endset %}
    {% do exceptions.warn(warning_msg) %}

    {{ return(None) }}

{% endmacro %}


{% macro snowflake__get_table_update_ts(resources) %}
    -- Query assumes database objects don't have case-sensitive names
    {% call statement("last_modified", fetch_result=True) %}
        {% for res in resources %}
            select
                '{{ res.resource }}' as resource,
                '{{ res.env }}' as env,
                table_catalog as database,
                table_schema as schema,
                table_name as name,
                last_altered 
            from {{ res.database }}.information_schema.tables
            where
                upper(table_schema) = upper('{{ res.schema }}')
                and upper(table_name) = upper('{{ res.name }}')

            {%- if not loop.last %} union all {% endif -%}
        {% endfor %}
    {% endcall %}

    {{ return(load_result("last_modified")) }}

{% endmacro %}


{% macro databricks__get_table_update_ts(resources) %}
    -- Query assumes database objects don't have case-sensitive names
    {% call statement("last_modified", fetch_result=True) %}
        {% for res in resources %}
            select
                '{{ res.resource }}' as resource,
                '{{ res.env }}' as env,
                table_catalog as database,
                table_schema as schema,
                table_name as name,
                last_altered 
            from system.information_schema.tables
            where
                table_catalog = '{{ res.database|lower }}'
                and table_schema = '{{ res.schema|lower }}'
                and table_name = '{{ res.name|lower }}'

            {% if not loop.last %} union all {% endif %}
        {% endfor %}
    {% endcall %}

    {{ return(load_result("last_modified")) }}

{% endmacro %}


{% macro bigquery__get_table_update_ts(resources) %}
    {% call statement("last_modified", fetch_result=True) %}
        {% for res in resources %}
            select
                '{{ res.resource }}' as resource,
                '{{ res.env }}' as env,
                inf_sch.table_catalog as database,
                inf_sch.table_schema as schema,
                inf_sch.table_name as name,
                coalesce(
                    timestamp_millis(meta.last_modified_time), 
                    inf_sch.creation_time
                ) as last_altered 
            from `{{ res.database }}.{{ res.schema }}.INFORMATION_SCHEMA.TABLES` inf_sch
            left join `{{ res.database }}.{{ res.schema }}.__TABLES__` meta
                on inf_sch.table_catalog = meta.project_id
                and inf_sch.table_schema = meta.dataset_id
                and inf_sch.table_name = meta.table_id
            where
                inf_sch.table_catalog = '{{ res.database|lower }}'
                and inf_sch.table_schema = '{{ res.schema|lower }}'
                and inf_sch.table_name = '{{ res.name|lower }}'

            {% if not loop.last %} union all {% endif %}
        {% endfor %}
    {% endcall %}

    {{ return(load_result("last_modified")) }}

{% endmacro %}
