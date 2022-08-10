{% macro ref(
    parent_model, 
    current_model=this.name, 
    prod_database=var("upstream_prod_database"), 
    prod_schema=var("upstream_prod_schema"),
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

    {# List models selected for current run #}
    {% set selected_models = [] %}
    {% for model in selected_resources %}
        {% if model.startswith("model.") %}
            {% do selected_models.append(model.split(".")[-1]) %}
        {% endif %}
    {% endfor %}

    {# Defer to prod for upstream models if they haven't been selected for the current run #}
    {% if current_model in selected_models and parent_model not in selected_models %}
        {# Account for warehouse-specific terms: https://docs.getdbt.com/reference/dbt-jinja-functions/target #}
        {% set target_database = target.database or target.dbname or target.project %}

        {% set parent_database = parent_ref.database | replace(target_database, prod_database) %}
        {% set parent_schema = parent_ref.schema | replace(target.schema, prod_schema) %}
        
        {% set parent_ref = adapter.get_relation(
                database=parent_database,
                schema=parent_schema,
                identifier=parent_ref.identifier
        ) %}
    {% endif %}
    
    {{ return(parent_ref) }}

{% endmacro %}
