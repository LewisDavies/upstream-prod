{{
    config(
        materialized = "incremental",
        incremental_strategy="microbatch",
        event_time="activity_date",
        batch_size="day",
        begin="2025-01-01",
        partition_by="activity_date"
    )
}}

select
    activity_date,
    current_timestamp() as updated_at
from {{ ref('stg__microbatch') }}
