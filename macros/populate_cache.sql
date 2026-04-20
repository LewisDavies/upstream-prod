{% macro populate_cache(parent_ids=none) %}
    {{ return(adapter.dispatch("populate_cache", "upstream_prod")(parent_ids)) }}
{% endmacro %}

{% macro default__populate_cache(parent_ids=none) %}

    {% if execute
        and var("upstream_prod_enabled", True)
        and var("upstream_prod_prefer_recent", False)
        and target.name not in var("upstream_prod_disabled_targets", [])
    %}
        {# Raise error if at least one required variable is not set #}
        {{ upstream_prod.check_reqd_vars(var("upstream_prod_database", None), var("upstream_prod_schema", None), var("upstream_prod_env_schemas", False), env_dbs=var("upstream_prod_env_dbs", False)) }}

        {# Default: derive parents from selected_resources (on-run-start path) #}
        {% if parent_ids is none %}
            {% set parent_ids = [] %}
            {% for resource in selected_resources %}
                {% for parent in graph.nodes[resource].depends_on.nodes %}
                    {% if parent.startswith("model.") and parent not in selected_resources %}
                        {% do parent_ids.append(parent) %}
                    {% endif %}
                {% endfor %}
            {% endfor %}
        {% endif %}

        {% set to_check = {} %}
        {% for parent_id in parent_ids %}
            {% set parent_node = graph.nodes[parent_id] %}
            {% set parent_name = parent_node["alias"] or parent_node["name"] %}
            {% set parent_resource = parent_node["package_name"] ~ "." ~ parent_name %}
            {% set prod_rel_db, prod_rel_schema, prod_rel_name = upstream_prod.get_prod_relation(parent_node, parent_node["database"], parent_node["schema"]) %}
            {{ upstream_prod.add_node_to_check(to_check, parent_node, prod_rel_db, prod_rel_schema, prod_rel_name, parent_resource, parent_name) }}
        {% endfor %}

        {# Run the query only if there are valid nodes to check. This is mainly a workaround for
        the integration_tests snapshots which don't use ref or source, it's probably quite rare for
        this pattern to appear in real models. #}
        {% if to_check | length > 0 %}
            {# Persist timestamps on the graph for the rest of the run #}
            {% if "_upstream_prod_cache" not in graph %}
                {% do graph.update({"_upstream_prod_cache": {}}) %}
            {% endif %}
            {% do graph["_upstream_prod_cache"].update(upstream_prod.get_node_timestamps(to_check)) %}
        {% endif %}

    {% endif %}

{% endmacro %}
