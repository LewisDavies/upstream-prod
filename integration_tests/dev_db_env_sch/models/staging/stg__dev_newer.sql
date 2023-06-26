select 
    '{{ target.name }}' as source_target,
    '{{ this.database }}' as source_database,
    '{{ this.schema }}' as source_schema,
    '{{ this.name }}' as source_model
    