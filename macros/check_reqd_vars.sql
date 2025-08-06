{% macro check_reqd_vars(prod_database, prod_schema, env_schemas, env_dbs) %}
    {{ return(adapter.dispatch("check_reqd_vars", "upstream_prod")(prod_database, prod_schema, env_schemas, env_dbs)) }}
{% endmacro %}

{% macro default__check_reqd_vars(prod_database, prod_schema, env_schemas, env_dbs) %}

    -- At least one of the variables below must be set for the package to function
    {% 
        if prod_database is none 
        and prod_schema is none 
        and env_schemas is false
        and env_dbs is false
    %}
        {% set error_msg -%}
upstream_prod is enabled but at least one required variable is missing.
Please set at least one of the following variables to correctly configure the package:
- upstream_prod_database
- upstream_prod_schema
- upstream_prod_env_schemas
- upstream_prod_env_dbs

The package can be disabled by setting the variable upstream_prod_enabled = False.
        {%- endset %}
        {% do exceptions.raise_compiler_error(error_msg) %}
    {% endif %}

    -- The env_dbs option also needs the prod db name to work properly
    {% if env_dbs is true and prod_database is none %}
        {% set error_msg -%}
upstream_prod_env_dbs is set to true but the production database name was not provided.
Please use the upstream_prod_database variable to set the database name.
        {%- endset %}
        {% do exceptions.raise_compiler_error(error_msg) %}
    {% endif %}

{% endmacro %}
