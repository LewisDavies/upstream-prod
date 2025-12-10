{{ config(event_time="activity_date") }}

select {{ dbt.current_timestamp() }} as activity_date
union all
select {{ dbt.dateadd("day", -1, dbt.current_timestamp()) }}
