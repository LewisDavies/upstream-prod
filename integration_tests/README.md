# Integration Tests

These instructions are intended to be used with Snowflake. They should work with other databases with minimal changes.

1. Add example profile to `profiles.yml`
2. Switch to a role with permission to create new databases.
3. Run all testing scripts
    - `sh run_db_tests.sh`
    - `sh run_env_schema_tests.sh`
    - `sh run_schema_tests.sh`

Check the output carefully as the script will continue even if a dbt run fails.
