{% macro check_reqd_vars(prod_database, prod_schema, env_schemas) %}
    {{ return(adapter.dispatch("check_reqd_vars", "upstream_prod")(prod_database, prod_schema, env_schemas)) }}
{% endmacro %}

{% macro default__check_reqd_vars(prod_database, prod_schema, env_schemas) %}

    {% 
        if prod_database is none 
        and prod_schema is none 
        and env_schemas == false
    %}
        {% set error_msg -%}
upstream_prod is enabled but at least one required variable is missing.
Please set at least one of the following variables to correctly configure the package:
- upstream_prod_database
- upstream_prod_schema
- upstream_prod_env_schemas

The package can be disabled by setting the variable upstream_prod_enabled = False.
        {%- endset %}
        {% do exceptions.raise_compiler_error(error_msg) %}
    {% endif %}

{% endmacro %}
