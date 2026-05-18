select activity_date
from {{ ref('stg__sample_flag') }}
