{% macro find_model_node(model, project, version) %}
    {{ return(adapter.dispatch("find_model_node", "upstream_prod")(model, project, version)) }}
{% endmacro %}

{% macro default__find_model_node(model, project, version) %}

    {% if execute is true %}
        -- For a while this macro checked the name against model aliases too. This
        -- caused issues when multiple models in the same project had the same alias.
        {% set matching_nodes = [] %}
        {% for n in graph.nodes.values() if n["name"] == model %}
            {% if project is none or project == n["package_name"] %}
                {% if version is not none %}
                    {% if n["version"] == version %}
                        {% do matching_nodes.append(n) %}
                    {% endif %}
                {% else %}
                    {% if n["version"] == n["latest_version"] %}
                        {% do matching_nodes.append(n) %}
                    {% endif %}
                {% endif %}
            {% endif %}
        {% endfor %}

        -- A one-arg ref may match the same model name in more than one package.
        -- This raises an error to match dbt's behaviour.
        {% if matching_nodes | length > 1 %}
            {% set candidate_ids = matching_nodes | map(attribute="unique_id") | join(", ") %}
            {% do exceptions.raise_compiler_error(
                "[upstream_prod] ref('" ~ model ~ "') is ambiguous: matched "
                ~ matching_nodes | length ~ " nodes (" ~ candidate_ids ~ "). "
                ~ "Use a two-argument ref to specify the package."
            ) %}
        {% endif %}

        {{ return(matching_nodes | first) }}
    {% endif %}

{% endmacro %}
