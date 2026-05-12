{% set rel = ref('seed__dev_newer') %}
select
    '{{ rel.database }}'   as source_database,
    '{{ rel.schema }}'     as source_schema,
    '{{ rel.identifier }}' as source_model,
    '{{ target.name }}'    as this_target,
    '{{ this.database }}'  as this_database,
    '{{ this.schema }}'    as this_schema,
    '{{ this.name }}'      as this_model
from {{ rel }}
