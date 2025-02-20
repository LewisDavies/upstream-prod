{% macro generate_database_name(custom_database_name=none, node=none, is_upstream_prod=False) -%}

    {%- set default_database = target.database -%}
    {%- if (target.name == "prod" or is_upstream_prod == true) and custom_database_name is not none -%}

        {{ custom_database_name | trim }}

    {%- else -%}

        {{ default_database }}

    {%- endif -%}

{%- endmacro %}
