{% macro ref(
    parent_model, 
    current_model=this.name, 
    prod_database=var("upstream_prod_database", None), 
    prod_schema=var("upstream_prod_schema", None),
    enabled=var("upstream_prod_enabled", True)
) %}
    {{ return(adapter.dispatch("ref", "upstream_prod")(parent_model, current_model, prod_database, prod_schema, enabled)) }}
{% endmacro %}

{% macro default__ref(parent_model, current_model, prod_database, prod_schema, enabled) %}

    {% set parent_ref = builtins.ref(parent_model) %}

    {# Return builtin ref when disabled or during prod runs #}
    {% if target.name in var("upstream_prod_disabled_targets", []) or not enabled %}
        {{ return(parent_ref) }}
    {% endif %}

    {# Raise error if neither the upstream database or schema are set #}
    {% if prod_database is none and prod_schema is none %}
        {% set error_msg -%}
upstream_prod is enabled but at least one required variable is missing.
Please set at least one of the following variables to correctly configure the package:
- upstream_prod_database
- upstream_prod_schema

The package can be disabled by setting the variable upstream_prod_enabled = False.
        {%- endset %}
        {% do exceptions.raise_compiler_error(error_msg) %}
    {% endif %}

    {# List models selected for current run #}
    {% set selected_models = [] %}
    {% for model in selected_resources %}
        {% if model.startswith("model.") or model.startswith("snapshot.") %}
            {% do selected_models.append(model.split(".")[-1]) %}
        {% endif %}
    {% endfor %}

    {# Defer to prod for upstream models not selected for the current run #}
    {% if current_model in selected_models and parent_model not in selected_models %}
        {% set parent_ref = adapter.get_relation(
                database=prod_database or parent_ref.database,
                schema=prod_schema or parent_ref.schema,
                identifier=parent_ref.identifier
        ) %}
    {% endif %}
    
    {{ return(parent_ref) }}

{% endmacro %}
