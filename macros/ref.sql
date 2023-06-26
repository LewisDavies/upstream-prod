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
    {{ return(adapter.dispatch("ref", "upstream_prod")(parent_model, prod_database, prod_schema, enabled, fallback, env_schemas, version, prefer_recent)) }}
{% endmacro %}

{% macro default__ref(parent_model, prod_database, prod_schema, enabled, fallback, env_schemas, version, prefer_recent) %}
    {% set parent_ref = builtins.ref(parent_model, version=version) %}
    {% set current_model = this.name if this is defined else 'unknown model' %}

    -- Return builtin ref for ephemeral models, during parsing or when disabled
    {% if execute == false or enabled == false or parent_ref.is_cte
        or target.name in var("upstream_prod_disabled_targets", []) %}
        {{ return(parent_ref) }}
    {% endif %}

    -- Raise error if at least one required variable is not set
    {{ upstream_prod.check_reqd_vars(prod_database, prod_schema, env_schemas) }}

    {% set selected = upstream_prod.find_selected_nodes(parent_model) %}
    -- Use dev relations for models being built during the current run
    {% if parent_model in selected %}
        {{ return(parent_ref) }}
    -- Try deferring to prod for non-selected upstream models
    {% else %}
        {% if env_schemas == true %}
            {% set parent_node = upstream_prod.find_model_node(parent_model, version) %}
            {% set custom_schema_name = parent_node.config.schema %}
            {% set parent_schema = generate_schema_name(custom_schema_name, parent_node, True) | trim %}
        -- No prod_schema = one-DB-per-env setup with same schema structure in all
        {% elif prod_schema is none %}
            {% set parent_schema = parent_ref.schema %}
        -- Schema structure is <env>[_<level>], e.g. prod, prod_stg or dev_int 
        {% else %}
            {% set parent_schema = parent_ref.schema | replace(target.schema, prod_schema) %}
        {% endif %}
        {% set parent_database = prod_database or parent_ref.database %}

        {% set prod_rel = adapter.get_relation(parent_database, parent_schema, parent_ref.table) %}
        {% set dev_rel = load_relation(parent_ref) %}
        {% set prod_exists = prod_rel is not none %}
        {% set dev_exists = dev_rel is not none %}

        {% if prod_exists %}
            -- When option enabled, return the mostly recently updated of dev & prod relations
            {% if prefer_recent and dev_exists %}
                -- Find when dev & prod relations were last updated
                {% set dev_updated = upstream_prod.get_table_update_ts(dev_rel) %}
                {% set prod_updated = upstream_prod.get_table_update_ts(prod_rel) %}

                {% if dev_updated > prod_updated %}
                    {{ log("[" ~ current_model ~ "] " ~ parent_ref.table ~ " fresher in dev than prod, switching to dev relation", info=True) }}
                    {{ return(dev_rel) }}
                {% else %}
                    {{ return(prod_rel) }}
                {% endif %}
            {% else %}
                {{ return(prod_rel) }}
            {% endif %}
        {% elif dev_exists %}
            -- Return dev relation if prod doesn't exist & option is enabled
            {% if fallback %}
                {{ log("[" ~ current_model ~ "] " ~ parent_ref.table ~ " not found in prod, falling back to default target", info=True) }}
                {{ return(dev_rel) }}
            {% else %}
                {{ upstream_prod.raise_ref_not_found_error(current_model, dev_rel) }}
            {% endif %}
        {% else %}
            {{ upstream_prod.raise_ref_not_found_error(current_model, prod_rel) }}
        {% endif %}

    {% endif %}
{% endmacro %}
