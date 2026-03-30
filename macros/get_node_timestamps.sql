{% macro get_node_timestamps(to_check) %}
    {{ return(adapter.dispatch("get_node_timestamps", "upstream_prod")(to_check)) }}
{% endmacro %}

{% macro default__get_node_timestamps(to_check) %}
    {% set checked = upstream_prod.query_table_last_altered(to_check) %}
    {% set output = {} %}
    {% if checked is not none %}
        {% for row in checked.data %}
            {% if row[0] not in output %}
                {% do output.update({row[0]: {}}) %}
            {% endif %}
            {% do output[row[0]].update({
                row[1]: {
                    "database": row[2],
                    "schema": row[3],
                    "name": row[4],
                    "last_altered": row[5]
                }
            }) %}
        {% endfor %}
    {% endif %}
    {{ return(output) }}
{% endmacro %}
