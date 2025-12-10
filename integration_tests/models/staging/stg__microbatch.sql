{{ config(event_time="activity_date") }}

select {{ dbt.date(2025, 1, 1) }} as activity_date
union all
select {{ dbt.date(2025, 1, 2) }}
