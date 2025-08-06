{% macro get_table_update_ts(relation) %}
    {{ return(adapter.dispatch("get_table_update_ts", "upstream_prod")(relation)) }}
{% endmacro %}

{% macro default__get_table_update_ts(relation) %}

    {% if target.type in ("snowflake", "databricks") %}
        -- Query assumes database objects don't have case-sensitive names
        {% set table_info_query %}
            select
                last_altered 
            from
                {{ relation.database }}.information_schema.tables
            where
                upper(table_catalog) = upper('{{ relation.database }}')
                and upper(table_schema) = upper('{{ relation.schema }}')
                and upper(table_name) = upper('{{ relation.identifier }}')
        {% endset %}
    {% elif target.type == "bigquery" %}
        {% set table_info_query %}
            select
                coalesce(
                    timestamp_millis(meta.last_modified_time), 
                    inf_sch.creation_time
                ) as last_altered
            from
                {{ relation.database }}.{{ relation.schema }}.INFORMATION_SCHEMA.TABLES inf_sch
                left join {{ relation.database }}.{{ relation.schema }}.__TABLES__ meta
                    on inf_sch.table_catalog = meta.project_id
                    and inf_sch.table_schema = meta.dataset_id
                    and inf_sch.table_name = meta.table_id
            where
                inf_sch.table_catalog = '{{ relation.database }}'
                and inf_sch.table_schema = '{{ relation.schema }}'
                and inf_sch.table_name = '{{ relation.identifier }}'
        {% endset %}
    {% else %}
        {% set warning_msg %}
upstream_prod_prefer_recent is set to true but this feature is incompatible with {{ target.type }} databases. Unsetting the variable may improve project performance.
        {% endset %}
        {% do exceptions.warn(warning_msg) %}
        {{ return(None) }}
    {% endif %}

    {{ return(dbt_utils.get_single_value(table_info_query, None)) }}

{% endmacro %}
