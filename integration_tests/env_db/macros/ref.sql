{% macro ref(
    parent_arg_1,
    parent_arg_2=None,
    prod_database=var("upstream_prod_database", None),
    prod_schema=var("upstream_prod_schema", None),
    enabled=var("upstream_prod_enabled", True),
    fallback=var("upstream_prod_fallback", False),
    env_schemas=var("upstream_prod_env_schemas", False),
    version=None,
    prefer_recent=var("upstream_prod_prefer_recent", False),
    env_dbs=var("upstream_prod_env_dbs", False)
) %}

    {% do return(upstream_prod.ref(
        parent_arg_1,
        parent_arg_2,
        prod_database,
        prod_schema,
        enabled,
        fallback,
        env_schemas,
        version,
        prefer_recent,
        env_dbs
    )) %}

{% endmacro %}
