{% macro ref(
    parent_model, 
    prod_database=var("upstream_prod_database", None), 
    prod_schema=var("upstream_prod_schema", None),
    enabled=var("upstream_prod_enabled", True),
    fallback=var("upstream_prod_fallback", False),
    env_schemas=var("upstream_prod_env_schemas", False),
    version=None,
    prefer_recent=var("upstream_prod_prefer_recent", False)
) %}

    {% do return(upstream_prod.ref(parent_model, prod_database, prod_schema, enabled, fallback, env_schemas, version)) %}

{% endmacro %}
