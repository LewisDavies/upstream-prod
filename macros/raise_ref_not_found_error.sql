{% macro raise_ref_not_found_error(current_model, relation) %}
    {{ return(adapter.dispatch("raise_ref_not_found_error", "upstream_prod")(current_model, relation)) }}
{% endmacro %}

{% macro default__raise_ref_not_found_error(current_model, relation) %}

    {% set error_msg -%}
[{{ current_model }}] upstream_prod couldnt find the specified model:

DATABASE: {{ relation.database }}
SCHEMA:   {{ relation.schema }}
RELATION: {{ relation.identifier }}

Check your variable settings in the README or create a GitHub issue for more help.
    {%- endset %}

    {% do exceptions.raise_compiler_error(error_msg) %}

{% endmacro %}
