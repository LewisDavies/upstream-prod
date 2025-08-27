select 
    *
from 
    {{ ref('defer_prod') }}
where
    this_model = 'This test should run but not fail'
