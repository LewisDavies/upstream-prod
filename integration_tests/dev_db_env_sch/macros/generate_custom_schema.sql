{% macro generate_schema_name(custom_schema_name, node, is_upstream_prod=False) -%}

    {%- set default_schema = target.schema -%}
    {%- if (target.name == "prod" or is_upstream_prod == true) and custom_schema_name is not none -%}

        {{ custom_schema_name | trim }}

    {%- else -%}

        {{ default_schema }}

    {%- endif -%}

{%- endmacro %}
