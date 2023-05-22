# Integration Tests

These instructions are intended to be used with Snowflake. They should work with other databases with minimal changes.

1. Add example profile to `profiles.yml`
2. Switch to a role with permission to create new databases.
3. Execute `sh run_tests.sh` for each test project and check the output for errors:
    - `dev_db`
    - `dev_db_dev_sch`
    - `dev_db_env_sch`
    - `dev_sch`
    - `env_sch`

## Notes
Files common to all projects are stored in the `_template` directory. They are symlinked with each test project with `create_symlinks.sh`.
