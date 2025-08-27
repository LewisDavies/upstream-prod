select count(*) as row_count
from {{ ref('defer_prod') }}
{% if flags.EMPTY %}
    having count(*) > 0
{% else %}
    limit 0
{% endif %}
