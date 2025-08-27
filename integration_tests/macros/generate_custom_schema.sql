{% macro generate_schema_name(custom_schema_name, node, is_upstream_prod=False) -%}

    {# This check isn't needed in regular projects.
    It is only included here so the package can easily be tested in a variety of configurations. #}
    {% if var("upstream_prod_env_schemas", false) is true %}

        {%- set default_schema = target.schema -%}
        {%- if (target.name == "prod" or is_upstream_prod is true) and custom_schema_name is not none -%}

            {{ custom_schema_name | trim }}

        {%- else -%}

            {{ default_schema }}

        {%- endif -%}
    
    {% else %}

        {{ return(dbt.generate_schema_name(custom_schema_name, node)) }}

    {% endif %}

{%- endmacro %}
