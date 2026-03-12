{% macro get_prod_relation(
    parent_node,
    dev_database,
    dev_schema,
    prod_database=var("upstream_prod_database", None),
    prod_schema=var("upstream_prod_schema", None),
    env_schemas=var("upstream_prod_env_schemas", False),
    env_dbs=var("upstream_prod_env_dbs", False)
) %}
    {{ return(adapter.dispatch("get_prod_relation", "upstream_prod")(parent_node, dev_database, dev_schema, prod_database, prod_schema, env_schemas, env_dbs)) }}
{% endmacro %}

{% macro default__get_prod_relation(parent_node, dev_database, dev_schema, prod_database, prod_schema, env_schemas, env_dbs) %}

    -- Set prod schema name
    {% if parent_node.resource_type == "snapshot"
        and parent_node.config.target_schema is defined
        and parent_node.config.target_schema is not none
    %}
        -- When target_schema is set the schema name is the same regardless of the environment.
        -- It is optional as of dbt v1.9. If it isn't set, the generate_schema_name macro is used
        -- in the same way as for models.
        {% set parent_schema = parent_node["schema"] %}
    {% elif env_schemas is true %}
        -- Schema generated with custom macro
        {% set custom_schema_name = parent_node.config.schema %}
        {% set parent_schema = generate_schema_name(custom_schema_name, parent_node, True) | trim %}
    {% elif prod_schema is none %}
        -- No prod_schema = one-DB-per-env setup with same schema structure in all
        {% set parent_schema = dev_schema %}
    {% else %}
        -- Schema structure is <env>[_<level>], e.g. prod, prod_stg or dev_int 
        {% set parent_schema = dev_schema | replace(target.schema, prod_schema) %}
    {% endif %}

    -- Set prod database name
    {% if env_dbs is true %}
        -- Database generated with custom macro
        {% set parent_database = generate_database_name(prod_database, parent_node, True) | trim %}
    {% else %}
        {% set parent_database = prod_database or dev_database %}
    {% endif %}

    /***************    
    prod_rel_name helps the package find the correct prod relation for projects using a custom 
    generate_alias_name macro. It assumes that custom aliases are only used in dev envs and prod
    relations always have the same name as the model (+ version suffix when needed).
    It's hacky but it seems to work. 
    ***************/
    {% set re = modules.re %}
    {% set prod_rel_name = re.search("\w+(?=\.)", parent_node.path).group() %}

    {{ return([parent_database, parent_schema, prod_rel_name]) }}

{% endmacro %}
