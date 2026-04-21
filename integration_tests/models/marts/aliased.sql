-- Refs a prod-only staging model with a persistent config(alias=...).
-- Tests that get_prod_relation uses the alias rather than the filename when
-- looking up an aliased model in prod.
select
    source_target,
    source_database,
    source_schema,
    source_model,
    '{{ target.name }}' as this_target,
    '{{ this.database }}' as this_database,
    '{{ this.schema }}' as this_schema,
    '{{ this.name }}' as this_model
from
    {{ ref('stg__aliased') }}
