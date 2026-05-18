{{ config(event_time="activity_date") }}

-- One row inside a typical --sample window, one row well outside.
-- Dates are dynamic so the test stays correct as time passes.
select {{ dbt.dateadd('day', -1, dbt.current_timestamp()) }} as activity_date
union all
select {{ dbt.dateadd('day', -30, dbt.current_timestamp()) }} as activity_date
