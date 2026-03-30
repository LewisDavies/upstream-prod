{% macro add_node_to_check(to_check, parent_node, prod_rel_db, prod_rel_schema, prod_rel_name, parent_resource, parent_name) %}
    {{ return(adapter.dispatch("add_node_to_check", "upstream_prod")(to_check, parent_node, prod_rel_db, prod_rel_schema, prod_rel_name, parent_resource, parent_name)) }}
{% endmacro %}

{% macro default__add_node_to_check(to_check, parent_node, prod_rel_db, prod_rel_schema, prod_rel_name, parent_resource, parent_name) %}
    {% set dev_db = parent_node["database"] %}
    {% set dev_schema = parent_node["schema"] %}
    {% if dev_db not in to_check %}
        {% do to_check.update({dev_db: {}}) %}
    {% endif %}
    {% if dev_schema not in to_check[dev_db] %}
        {% do to_check[dev_db].update({dev_schema: []}) %}
    {% endif %}
    {% do to_check[dev_db][dev_schema].append({
        "resource": parent_resource,
        "env": "dev",
        "name": parent_name
    }) %}

    {% if prod_rel_db not in to_check %}
        {% do to_check.update({prod_rel_db: {}}) %}
    {% endif %}
    {% if prod_rel_schema not in to_check[prod_rel_db] %}
        {% do to_check[prod_rel_db].update({prod_rel_schema: []}) %}
    {% endif %}
    {% do to_check[prod_rel_db][prod_rel_schema].append({
        "resource": parent_resource,
        "env": "prod",
        "name": prod_rel_name
    }) %}
{% endmacro %}
