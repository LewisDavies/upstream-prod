{% macro generate_database_name(custom_database_name=none, node=none, is_upstream_prod=False) -%}

    {# This check isn't needed in regular projects.
    It is only included here so the package can easily be tested in a variety of configurations. #}
    {% if var("upstream_prod_env_dbs", false) is true %}

        {%- set default_database = target.database -%}
        {%- if (target.name == "prod" or is_upstream_prod is true) and custom_database_name is not none -%}

            {{ custom_database_name | trim }}

        {%- else -%}

            {{ default_database }}

        {%- endif -%}

    {% else %}

        {{ return(dbt.generate_database_name(custom_database_name, node)) }}

    {% endif %}

{%- endmacro %}
