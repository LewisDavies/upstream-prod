{% macro ref(
    parent_model, 
    current_model=this.name, 
    prod_database=var("upstream_prod_database", None), 
    prod_schema=var("upstream_prod_schema", None),
    enabled=var("upstream_prod_enabled", True),
    fallback=var("upstream_prod_fallback", False),
    env_schemas=var("upstream_prod_env_schemas", False)
) %}
    {{ return(adapter.dispatch("ref", "upstream_prod")(parent_model, current_model, prod_database, prod_schema, enabled, fallback, env_schemas)) }}
{% endmacro %}

{% macro default__ref(parent_model, current_model, prod_database, prod_schema, enabled, fallback, env_schemas) %}

    {% set parent_ref = builtins.ref(parent_model) %}

    {# Return builtin ref during parsing or when disabled #}
    {% if not execute or target.name in var("upstream_prod_disabled_targets", []) or not enabled %}
        {{ return(parent_ref) }}
    {% endif %}

    {# Return builtin ref for tests #}
    {% if execute %}
        {% set current_node = (graph.nodes.values()
            | selectattr("alias", "equalto", current_model) 
            | list).pop() %}
        {% if current_node.resource_type == 'test' %}
            {{ return(parent_ref) }}
        {% endif %}
    {% endif %}

    {# Raise error if neither the upstream database or schema are set #}
    {% if prod_database is none and prod_schema is none and not custom_schemas %}
        {% set error_msg -%}
upstream_prod is enabled but at least one required variable is missing.
Please set at least one of the following variables to correctly configure the package:
- upstream_prod_database
- upstream_prod_schema
- upstream_prod_custom_schemas

The package can be disabled by setting the variable upstream_prod_enabled = False.
        {%- endset %}
        {% do exceptions.raise_compiler_error(error_msg) %}
    {% endif %}

    {# List models selected for current run #}
    {% set selected_models = [] %}
    {% for res in selected_resources %}
        {% if res.startswith("model.") or res.startswith("snapshot.") %}
            {% do selected_models.append(res.split(".")[-1]) %}
        {% endif %}
    {% endfor %}

    {# Defer to prod for upstream models not selected for this run #}
    {% if current_model in selected_models %}
        {% if parent_model in selected_models %}
            {{ return(parent_ref) }}
        {% else %}
            {# Use parent ref schema when upstream schema is not set #}
            {% if env_schemas %}
                {% if execute %}
                    {% set parent_node = (graph.nodes.values() 
                        | selectattr("name", "equalto", parent_model)
                        | list).pop() %}
                    {% set parent_schema = parent_node.config.schema or prod_schema %}
                {% endif %}
            {% elif prod_schema is none %}
                {% set parent_schema = parent_ref.schema %}
            {% else %}
                {% set parent_schema = parent_ref.schema | replace(target.schema, prod_schema) %}
            {% endif %}
            
            {% set prod_ref = adapter.get_relation(
                    database=prod_database or parent_ref.database,
                    schema=parent_schema,
                    identifier=parent_model
            ) %}

            {% if prod_ref is none and fallback %}
                {{ log("[" ~ current_model ~ "] " ~ parent_model ~ " not found in prod, falling back to default target", info=True) }}
                {{ return(parent_ref) }}
            {% else %}
                {{ return(prod_ref) }}
            {% endif %}
        {% endif %}
    {% endif %}

{% endmacro %}
