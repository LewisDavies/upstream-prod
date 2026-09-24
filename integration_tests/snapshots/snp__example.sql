{% snapshot snp__example %}

{{
    config(
        unique_key="id",
        strategy="timestamp",
        updated_at="updated_at",
    )
}}

select
    '{{ target.name }}' as source_target,
    '{{ this.database }}' as source_database,
    '{{ this.schema }}' as source_schema,
    '{{ this.name }}' as source_model,
    1 as id,
    cast(current_timestamp as {{ dbt.type_timestamp() }}) as updated_at

{% endsnapshot %}
