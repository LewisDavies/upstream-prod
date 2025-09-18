{% macro create_test_db(db) -%}

    {% if target.type == "snowflake" %}
        {% do run_query("create or replace database " ~ db) %}
    {% elif target.type == "databricks" %}
        {% do run_query("drop catalog if exists " ~ db ~ " cascade") %}
        {% do run_query("create catalog " ~ db) %}
    {% elif target.type == "bigquery" %}
        {% set schema_query %}
            select
                concat(catalog_name, '.', schema_name) as full_schema
            from `{{ db }}`.INFORMATION_SCHEMA.SCHEMATA
        {% endset %}
        {%- set schemas = dbt_utils.get_query_results_as_dict(schema_query) -%}

        {% for sch in schemas["full_schema"] %}
            {% do run_query("drop schema " ~ sch ~ " cascade") %}
        {% endfor %}
    {% endif %}

{%- endmacro %}
