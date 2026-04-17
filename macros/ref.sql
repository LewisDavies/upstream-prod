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
    {{ return(adapter.dispatch("ref", "upstream_prod")(parent_arg_1, parent_arg_2, prod_database, prod_schema, enabled, fallback, env_schemas, version, prefer_recent, env_dbs)) }}
{% endmacro %}

{% macro default__ref(parent_arg_1, parent_arg_2, prod_database, prod_schema, enabled, fallback, env_schemas, version, prefer_recent, env_dbs) %}
    /***************
    Handle two-argument refs

    For packages, the project name is the name of the package, e.g. model.facebook_ads.facebook_ads__account_report,
    so we can't simply use the user's project name when one isn't supplied. Instead we will match on just the model
    name - not project + model name - when only one arg (the model name) is supplied.
    ***************/
    {% if parent_arg_2 is none %}
        {% set parent_project = None %}
        {% set parent_model = parent_arg_1 %}
        {% set parent_ref = builtins.ref(parent_model, version=version) %}
    {% else %}
        {% set parent_project = parent_arg_1 %}
        {% set parent_model = parent_arg_2 %}
        {% set parent_ref = builtins.ref(parent_project, parent_model, version=version) %}
    {% endif %}
    {% set current_model = this.name if this is defined else "unknown model" %}

    -- Return builtin ref for ephemeral models, during parsing or when disabled
    {% if execute is false
        or enabled is false
        or parent_ref.is_cte
        or target.name in var("upstream_prod_disabled_targets", [])
    %}
        {{ return(parent_ref) }}
    {% endif %}

    -- Raise error if at least one required variable is not set
    {{ upstream_prod.check_reqd_vars(prod_database, prod_schema, env_schemas, env_dbs) }}

    {% set selected = upstream_prod.find_selected_nodes(parent_model, parent_project) %}
    -- Use dev relations for models being built during the current run
    {% if parent_model in selected %}
        {{ return(parent_ref) }}
    -- Find prod version of parent ref
    {% else %}
        {% set parent_node = upstream_prod.find_model_node(parent_model, parent_project, version) %}
        {% set prod_rel_db, prod_rel_schema, prod_rel_name = upstream_prod.get_prod_relation(parent_node, parent_node["database"], parent_node["schema"]) %}
        {% set prod_rel = adapter.get_relation(prod_rel_db, prod_rel_schema, prod_rel_name) %}
        {% set dev_rel = load_relation(parent_ref) %}
        {% set prod_exists = prod_rel is not none %}
        {% set dev_exists = dev_rel is not none %}

        -- Default to returning the prod relation, but override in the circumstances outlined below
        {% set return_rel = prod_rel %}

        {% if prod_exists is true %}
            -- When option enabled, return the most recently updated of dev & prod relations
            {% if prefer_recent is true and dev_exists is true %}
                {% set parent_name = parent_node["alias"] or parent_node["name"] %}
                {% set parent_resource = parent_node["package_name"] ~ "." ~ parent_name %}

                -- On cache miss, batch-cache all of the current node's ref'd parents in a single query
                {% if "_upstream_prod_cache" not in graph or parent_resource not in graph["_upstream_prod_cache"] %}
                    {# model.depends_on.nodes is populated for both real models and synthesised
                       sql_operations (e.g. dbt show --inline), so works in both contexts. #}
                    {% set all_parents = model.depends_on.nodes if (model is defined and model.depends_on is defined) else [parent_node["unique_id"]] %}
                    {% set parent_ids = [] %}
                    {% for p in all_parents %}
                        {% if p.startswith("model.") %}
                            {% do parent_ids.append(p) %}
                        {% endif %}
                    {% endfor %}
                    {{ upstream_prod.populate_cache(parent_ids) }}
                {% endif %}

                -- Return dev relation if it exists and is fresher than prod
                {% set cached_resource = graph["_upstream_prod_cache"].get(parent_resource) if "_upstream_prod_cache" in graph else none %}
                {% if cached_resource is not none and cached_resource["dev"]["last_altered"] | string > cached_resource["prod"]["last_altered"] | string %}
                    {{ log("[" ~ current_model ~ "] " ~ parent_ref.table ~ " fresher in dev than prod, switching to dev relation", info=True) }}
                    {% set return_rel = dev_rel %}
                {% endif %}
            {% endif %}
        {% elif dev_exists %}
            -- Return dev relation if prod doesn't exist & fallback is enabled
            {% if fallback is true %}
                {{ log("[" ~ current_model ~ "] " ~ parent_ref.table ~ " not found in prod, falling back to default target", info=True) }}
                {% set return_rel = dev_rel %}
            {% else %}
                {{ upstream_prod.raise_ref_not_found_error(current_model, parent_ref.database, parent_ref.schema, parent_ref.name) }}
            {% endif %}
        {% else %}
            {{ upstream_prod.raise_ref_not_found_error(current_model, prod_rel_db, prod_rel_schema, prod_rel_name) }}
        {% endif %}

        -- Carry over limit (--empty) and event_time_filter (microbatch/--sample) from the builtin ref
        {% set return_rel = return_rel.replace(limit=parent_ref.limit, event_time_filter=parent_ref.event_time_filter) %}
        {{ return(return_rel) }}

    {% endif %}
{% endmacro %}
