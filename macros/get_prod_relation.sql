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
    prod_rel_name identifies the correct prod relation. There are two cases:
    1. A persistent `config(alias=...)` on the model — the alias is the real name in both
       environments, so we use it directly.
    2. Otherwise — the alias may be a dev-only override set by a custom `generate_alias_name`
       macro, so we fall back to the filename (+ version suffix when needed).
    ***************/
    {% set re = modules.re %}
    {% if parent_node.config.alias is not none %}
        {% set prod_rel_name = parent_node.config.alias %}
    {% else %}
        {% set prod_rel_name = re.search("\w+(?=\.)", parent_node.path).group() %}
    {% endif %}

    {{ return([parent_database, parent_schema, prod_rel_name]) }}

{% endmacro %}
