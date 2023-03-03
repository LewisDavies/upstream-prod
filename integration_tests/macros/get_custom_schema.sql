{% macro generate_schema_name(custom_schema_name, node) -%}
    {% if var('upstream_prod_env_schemas', False) %}
        {{ generate_schema_name_for_env(custom_schema_name, node) }}
    {% else %}
        {{ adapter.dispatch('generate_schema_name', 'dbt')(custom_schema_name, node) }}
    {% endif %}
{%- endmacro %}
