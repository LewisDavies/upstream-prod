# Integration Tests

These instructions are intended to be used with Snowflake. They should work with other databases with minimal changes.

1. Add example profile to `profiles.yml`
2. Set up databases (Snowflake)
    ```sql
    create or replace database upstream_prod__prod_db;
    create or replace database upstream_prod__dev_db;

    grant all on database upstream_prod__prod_db to role <your-role>;
    grant all on database upstream_prod__dev_db to role <your-role>;
    ```
3. Run commands
    ```sh
    # Using dev schemas
    dbt run -s stg__dev_fallback --vars 'upstream_prod_schema: prod' --target dev
    dbt build -s dev_fallback --vars 'upstream_prod_schema: prod' --target dev
    dbt run -s stg__defer_prod--vars 'upstream_prod_schema: prod' --target prod
    dbt build -s defer_prod --vars 'upstream_prod_schema: prod' --target dev
    # Using dev env schemas
    dbt run -s stg__dev_fallback --vars '{upstream_prod_schema: prod, upstream_prod_env_schemas: true}' --target dev
    dbt build -s dev_fallback --vars '{upstream_prod_schema: prod, upstream_prod_env_schemas: true}' --target dev
    dbt run -s stg__defer_prod --vars '{upstream_prod_schema: prod, upstream_prod_env_schemas: true}' --target prod
    dbt build -s defer_prod --vars '{upstream_prod_schema: prod, upstream_prod_env_schemas: true}' --target dev
    # Using dev databases
    dbt run -s stg__dev_fallback --vars 'upstream_prod_database: upstream_prod__prod_db' --target dev_db
    dbt build -s dev_fallback --vars 'upstream_prod_database: upstream_prod__prod_db' --target dev_db
    dbt run -s stg__defer_prod --vars 'upstream_prod_database: upstream_prod__prod_db' --target prod_db
    dbt build -s defer_prod --vars 'upstream_prod_database: upstream_prod__prod_db' --target dev_db
    ```
