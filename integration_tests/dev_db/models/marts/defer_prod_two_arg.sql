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
    {{ ref('upstream_prod_integration_tests', 'stg__defer_prod') }}
