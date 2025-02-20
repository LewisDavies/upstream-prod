{% macro create_test_db(db) -%}

    {% if target.type == "snowflake" %}
        {% do run_query("create or replace database " ~ db) %}
    {% elif target.type == "databricks" %}
        {% do run_query("drop catalog if exists " ~ db ~ " cascade") %}
        {% do run_query("create catalog " ~ db) %}
    {% endif %}

{%- endmacro %}
