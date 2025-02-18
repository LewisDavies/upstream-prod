# Integration Tests

These instructions are intended to be used with Snowflake. They should work with other databases with minimal changes.

1. Add example profile to `profiles.yml`
1. Switch to a role with permission to create new databases.
1. Change to the `integration_tests` directory.
1. Execute `sh test_all_projects.sh`.

## Notes
Files common to all projects are stored in the `_template` directory. They are symlinked with each test project whenever `test_all_projects.sh` runs.
