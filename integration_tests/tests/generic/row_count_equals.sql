{% test row_count_equals(model, expected) %}
    select 1 as failure
    from (select count(*) as n from {{ model }}) c
    where c.n != {{ expected }}
{% endtest %}
