{% macro ref(
    parent_model, 
    prod_database=var("upstream_prod_database", None), 
    prod_schema=var("upstream_prod_schema", None),
    enabled=var("upstream_prod_enabled", True),
    fallback=var("upstream_prod_fallback", False),
    env_schemas=var("upstream_prod_env_schemas", False),
    version=None
) %}
    {{ return(adapter.dispatch("ref", "upstream_prod")(parent_model, prod_database, prod_schema, enabled, fallback, env_schemas, version)) }}
{% endmacro %}

{% macro default__ref(parent_model, prod_database, prod_schema, enabled, fallback, env_schemas, version) %}
    {% set parent_ref = builtins.ref(parent_model, version=version) %}
    {% set current_model = this.name if this is defined else 'unknown model' %}

    -- Return builtin ref during parsing or when disabled
    {% 
        if execute == false
        or enabled == false
        or target.name in var("upstream_prod_disabled_targets", []) 
    %}
        {{ return(parent_ref) }}
    {% endif %}

    -- Raise error if at least one required variable is not set
    {% 
        if prod_database is none 
        and prod_schema is none 
        and env_schemas == false
    %}
        {% set error_msg -%}
upstream_prod is enabled but at least one required variable is missing.
Please set at least one of the following variables to correctly configure the package:
- upstream_prod_database
- upstream_prod_schema
- upstream_prod_env_schemas

The package can be disabled by setting the variable upstream_prod_enabled = False.
        {%- endset %}
        {% do exceptions.raise_compiler_error(error_msg) %}
    {% endif %}

    /*******************
    Note on selection & tests

    The selected_resources variable is a list of all nodes to be executed on the current run.
    Below are some example elements:
    1. model.my_project.my_model
    2. snapshot.my_project.my_snapshot
    3. test.unique_my_model_id.<hash>

    In a nutshell, when ref() is called this package checks if the model is included in this 
    list and returns the appropriate relation. However, running a test (e.g. dbt test -s my_model) 
    only adds the test name (i.e. element 3) to selected_resources. The graph variable is used 
    to identify the models relied on by each test.

    Some tests rely on multiple models, such as relationship tests. For these, the package returns
    the dev relation for explicity selected models and tries to fetch prod relations for comparison
    models.
    
    Example: my_model has a relationship test against my_stg_model and dbt test -s my_model is run.
    As my_model was explicitly selected by the user, the dev relation is used as the base and is
    compared to the prod version of my_stg_model.
    /*******************/

    -- Find models & snapshots selected for current run
    {% set selected = [] %}
    {% set selected_tests = [] %}
    {% for res in selected_resources %}
        {% if not res.startswith("test.") %}
            {% do selected.append(res.split(".")[2]) %}
        {% else %}
            {% do selected_tests.append(res) %}
        {% endif %}
    {% endfor %}

    -- Find models being tested
    {% for test in selected_tests %}
        {% set tested_model = graph.nodes[test].file_key_name.split(".")[1] %}
        -- Return dev relation for explicitly selected models
        {% if parent_model == tested_model %}
            {{ return(parent_ref) }}
        {% endif %}
    {% endfor %}

    -- Use dev relations for models being built during the current run
    {% if parent_model in selected %}
        {{ return(parent_ref) }}
    -- Try deferring to prod for non-selected upstream models
    {% else %}
        -- Find parent node, accounting for (un)specified model version
        {% set matching_nodes = [] %}
        {% for n in graph.nodes.values() if n["name"] == parent_model %}
            {% if version is not none %}
                {% if n["version"] == version %}
                    {% do matching_nodes.append(n) %}
                {% endif %}
            {% else %}
                {% if n["version"] == n["latest_version"] %}
                    {% do matching_nodes.append(n) %}
                {% endif %}
            {% endif %}
        {% endfor %}
        {% set parent_node = matching_nodes | first %}

        -- Use builtin ref for ephemeral models
        {% if parent_node.config.materialized == "ephemeral" %}
            {{ return(parent_ref) }}
        -- When using env schemas, use the graph to find the schema name that would be used in production environments
        {% elif env_schemas == true %}
            {% set custom_schema_name = parent_node.config.schema %}
            {% set parent_schema = generate_schema_name(custom_schema_name, parent_node, True) | trim %}
        -- No prod_schema value means a one-DB-per-developer setup, so assume schema names are consistent across
        -- environments and use the schema name from the default parent ref
        {% elif prod_schema is none %}
            {% set parent_schema = parent_ref.schema %}
        -- Reaching here means each developer has a separate set of schemas with different prefixes, which can
        -- be identified with a simple find-and-replace
        {% else %}
            {% set parent_schema = parent_ref.schema | replace(target.schema, prod_schema) %}
        {% endif %}

        -- Build final ref and check that it exists
        {% set parent_database = prod_database or parent_ref.database %}
        {% set return_ref = adapter.get_relation(parent_database, parent_schema, parent_ref.table) %}

        -- If prod relation doesn't exist and fallback is enabled, try the dev relation instead.
        {% if return_ref is none and fallback == true %}
            {{ log("[" ~ current_model ~ "] " ~ parent_ref.table ~ " not found in prod, falling back to default target", info=True) }}
            {% set return_ref = load_relation(parent_ref) %}
        {% endif %}

        -- Return final ref, or raise error if relation isn't found
        {% if return_ref is not none %}
            {{ return(return_ref) }}
        {% else %}
            {% set error_msg -%}
[{{ current_model }}] upstream_prod couldn't find the specified model:

DATABASE: {{ parent_database }}
SCHEMA:   {{ parent_schema }}
RELATION: {{ parent_ref.table }}

Check your variable settings in the README or create a GitHub issue for more help.
            {%- endset %}
            {% do exceptions.raise_compiler_error(error_msg) %}
        {% endif %}

    {% endif %}
{% endmacro %}
