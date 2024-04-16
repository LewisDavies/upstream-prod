{% macro check_reqd_vars(prod_database, prod_schema, env_schemas, prod_database_replace) %}
    {{ return(adapter.dispatch("check_reqd_vars", "upstream_prod")(prod_database, prod_schema, env_schemas, prod_database_replace)) }}
{% endmacro %}

{% macro default__check_reqd_vars(prod_database, prod_schema, env_schemas, prod_database_replace) %}

    -- At least one of the variables below must be set for the package to function
    {% 
        if prod_database is none 
        and prod_schema is none 
        and env_schemas == false
        and prod_database_replace is none
    %}
        {% set error_msg -%}
upstream_prod is enabled but at least one required variable is missing.
Please set at least one of the following variables to correctly configure the package:
- upstream_prod_database
- upstream_prod_database_replace
- upstream_prod_schema
- upstream_prod_env_schemas

The package can be disabled by setting the variable upstream_prod_enabled = False.
        {%- endset %}
        {% do exceptions.raise_compiler_error(error_msg) %}
    {% endif %}

    -- The variables below are incompatible so only one should be provided
    {% if prod_database is not none and prod_database_replace is not none %}
        {% set error_msg -%}
upstream_prod has been provided with two incompatible variables. Only one of the following should be set:
- upstream_prod_database
- upstream_prod_database_replace
        {%- endset %}
        {% do exceptions.raise_compiler_error(error_msg) %}
    {% endif %}

{% endmacro %}
