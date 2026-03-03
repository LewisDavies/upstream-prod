{% macro populate_cache() %}
    {{ return(adapter.dispatch("populate_cache", "upstream_prod")()) }}
{% endmacro %}

{% macro default__populate_cache() %}

    {% if execute 
        and var("upstream_prod_enabled", True)
        and var("upstream_prod_prefer_recent", False)
        and target.name not in var("upstream_prod_disabled_targets", [])
    %}
    {# Raise error if at least one required variable is not set #}
    {{ upstream_prod.check_reqd_vars(var("upstream_prod_database", None), var("upstream_prod_schema", None), var("upstream_prod_env_schemas", False), env_dbs=var("upstream_prod_env_dbs", False)) }}

        {# Find parents of selected models #}
        {% set to_check = [] %}
        {% for resource in selected_resources %}
            {% set node = graph.nodes[resource] %}
            {% for parent in node.depends_on.nodes %}
                {# Find parent models excluding those selected on the current run #}
                {% if parent.startswith("model.") and parent not in selected_resources %}
                    {# Find parent on the graph to get relation info #}
                    {% set parent_node = graph.nodes[parent] %}
                    {% set parent_name = parent_node["alias"] or parent_node["name"] %}
                    {% set parent_resource = parent_node["package_name"] ~ "." ~ parent_name %}

                    {# Add dev relation to check list #}
                    {% do to_check.append({
                        "resource": parent_resource,
                        "env": "dev",
                        "database": parent_node["database"],
                        "schema": parent_node["schema"],
                        "name": parent_node["alias"] or parent_node["name"]
                    }) %}

                    {# Find prod relation and add to check list #}
                    {% set prod_rel_db, prod_rel_schema, prod_rel_name = upstream_prod.get_prod_relation(parent_node, parent_node["database"], parent_node["schema"]) %}
                    {% do to_check.append({
                        "resource": parent_resource,
                        "env": "prod",
                        "database": prod_rel_db,
                        "schema": prod_rel_schema,
                        "name": prod_rel_name
                    }) %}
                {% endif %}
            {% endfor %}
        {% endfor %}

        {# Run the query only if there are valid nodes to check. This is mainly a workaround for
        the integration_tests snapshots which don't use ref or source, it's probably quite rare for
        this pattern to appear in real models. #}
        {% if to_check | length > 0 %}
            {# Get timestamps of last update #}
            {% set checked = upstream_prod.get_table_update_ts(to_check) %}

            {% set output = {} %}
            {% for row in checked.data %}
                {# Add dict for each relation #}
                {% if row[0] not in output %}
                    {% do output.update({row[0]: {}}) %}
                {% endif %}
                {# Add sub-dict for dev and prod (if they exist) #}
                {% do output[row[0]].update({
                    row[1]: {
                        "database": row[2],
                        "schema": row[3],
                        "name": row[4],
                        "last_altered": row[5]
                    }
                }) %}
            {% endfor %}

            {# Persist timestamps on the graph for the rest of the run #}
            {% do graph.update({"_upstream_prod_cache": output}) %}
        {% endif %}

    {% endif %}

{% endmacro %}
