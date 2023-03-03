select env from {{ ref('stg__dev_fallback', fallback=True) }}
