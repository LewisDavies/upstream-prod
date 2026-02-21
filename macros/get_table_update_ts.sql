/***************
This is where the freshest relation is determined if prefer_recent is enabled.

It originally used custom queries that only handled Snowflake, Databricks and BigQuery.
I later switched to get_relation_last_modified to add support for a wider range of adapters.
This had the nice side effect of adding support for Hive metastore on Databricks.

The original implementation was kept for BQ compatibility, which only implemented
get_relation_last_modified in 2026.
***************/

{% macro get_table_update_ts(relation) %}
    -- Create run-level cache
    {% if "_upstream_prod_ts_cache" not in graph %}
        {% do graph.update({"_upstream_prod_ts_cache": {}}) %}
    {% endif %}
    
    -- Use cached update timestamp if available
    {% set cache_key = (relation.database ~ "." ~ relation.schema ~ "." ~ relation.identifier) | lower %}
    {% if cache_key in graph["_upstream_prod_ts_cache"] %}
        {{ return(graph["_upstream_prod_ts_cache"][cache_key]) }}
    {% endif %}

    -- Find & cache timestamp from information_schema (or similar)
    {% set result = adapter.dispatch("get_table_update_ts", "upstream_prod")(relation) %}
    {% do graph["_upstream_prod_ts_cache"].update({cache_key: result}) %}
    {{ return(result) }}

{% endmacro %}

{% macro default__get_table_update_ts(relation) %}
    /***************
    This is the same macro used by the source freshness command. It accepts a list so
    it could technically check prod & dev in one call if both relations are in the same
    database. I decided it wasn't worth the hassle as it would add complexity.
    ***************/
    {% set rel_updated = adapter.dispatch("get_relation_last_modified")(
        relation.information_schema(),
        [relation]
    ).table.rows[0][2] %}

    {{ return(rel_updated) }}

{% endmacro %}

{% macro bigquery__get_table_update_ts(relation) %}
    {% set table_info_query %}
        select
            coalesce(
                timestamp_millis(meta.last_modified_time), 
                inf_sch.creation_time
            ) as last_altered
        from
            `{{ relation.database }}.{{ relation.schema }}.INFORMATION_SCHEMA.TABLES` inf_sch
            left join `{{ relation.database }}.{{ relation.schema }}.__TABLES__` meta
                on inf_sch.table_catalog = meta.project_id
                and inf_sch.table_schema = meta.dataset_id
                and inf_sch.table_name = meta.table_id
        where
            inf_sch.table_catalog = '{{ relation.database }}'
            and inf_sch.table_schema = '{{ relation.schema }}'
            and inf_sch.table_name = '{{ relation.identifier }}'
    {% endset %}

    {{ return(dbt_utils.get_single_value(table_info_query, None)) }}

{% endmacro %}
