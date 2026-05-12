{% set rel = ref('seed__dev_newer') %}
select
    '{{ rel.database | lower }}'   as source_database,
    '{{ rel.schema | lower }}'     as source_schema,
    '{{ rel.identifier | lower }}' as source_model,
    '{{ target.name }}'            as this_target,
    '{{ this.database }}'          as this_database,
    '{{ this.schema }}'            as this_schema,
    '{{ this.name }}'              as this_model
from {{ rel }}
