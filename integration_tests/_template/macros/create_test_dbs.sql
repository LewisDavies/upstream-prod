{% macro create_test_db(db) -%}
    {% do run_query('create or replace database ' ~ db) %}
{%- endmacro %}
