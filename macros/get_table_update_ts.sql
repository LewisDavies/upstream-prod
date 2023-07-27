{% macro get_table_update_ts(relation) %}
    {{ return(adapter.dispatch("get_table_update_ts", "upstream_prod")(relation)) }}
{% endmacro %}

{% macro snowflake__get_table_update_ts(relation) %}

    {% set table_info_query %}
        select
            last_altered 
        from
            {{ relation.database }}.information_schema.tables
        where
            table_catalog = upper('{{ relation.database }}')
            and table_schema = upper('{{ relation.schema }}')
            and table_name = upper('{{ relation.identifier }}')
    {% endset %}

    {% set result = run_query(table_info_query) %}
    {% if result | length == 0 %}
        {{ return(None) }}
    {% elif result | length > 1 %}
        {% set error_msg %}
Multiple matches in information schema for {{ relation }}
        {% endset %}
        {% do exceptions.raise_compiler_error(error_msg) %}
    {% else %}
        {{ return(result.rows.values()[0][0] ) }}
    {% endif %}
    
{% endmacro %}

{% macro bigquery__get_table_update_ts(relation) %}

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

    {% set result = run_query(table_info_query) %}
    {% if result | length == 0 %}
        {{ return(None) }}
    {% elif result | length > 1 %}
        {% set error_msg %}
Multiple matches in information schema for {{ relation }}
        {% endset %}
        {% do exceptions.raise_compiler_error(error_msg) %}
    {% else %}
        {{ return(result.rows.values()[0][0] ) }}
    {% endif %}
    
{% endmacro %}
