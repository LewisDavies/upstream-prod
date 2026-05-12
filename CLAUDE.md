# upstream-prod

A dbt package that overrides `ref()` to resolve references against production data in development environments.

## Commands

```bash
make setup           # Create .venv and .env from .env.example
make test            # Integration tests on all platforms
make test-snowflake  # Single platform (also test-databricks, test-bigquery)
```

## Architecture

All logic lives in `macros/`. The package works by overriding dbt's built-in `ref()` macro:

| Macro | Purpose |
|---|---|
| `ref.sql` | Entry point — dispatches to `default__ref`, which decides whether to return a dev or prod relation |
| `get_prod_relation.sql` | Resolves the prod database/schema/name for a given node |
| `find_model_node.sql` | Looks up a node in `graph.nodes` by model name |
| `find_selected_nodes.sql` | Returns the set of models selected in the current run |
| `populate_cache.sql` | `on-run-start` hook — pre-fetches timestamps for all unselected parent nodes (models, seeds, snapshots) and stores them in `graph["_upstream_prod_cache"]` |
| `query_table_last_altered.sql` | Adapter-dispatched SQL — queries `information_schema` for `last_altered` timestamps. Returns a raw result set. |
| `get_node_timestamps.sql` | Calls `query_table_last_altered`, parses result rows into `{resource: {env: {database, schema, name, last_altered}}}` |
| `add_node_to_check.sql` | Mutates a `to_check` dict in place to add dev and prod entries for a single node (shared between `populate_cache` and the `ref` slow path) |
| `check_reqd_vars.sql` | Validates required variables are set |
| `raise_ref_not_found_error.sql` | Raises a consistent error when a relation can't be found |

### `prefer_recent` flow

When `upstream_prod_prefer_recent: true` is set:

1. `populate_cache` runs via `on-run-start`, querying timestamps for all unselected parent nodes (models, seeds, snapshots) and storing them in `graph["_upstream_prod_cache"]`.
2. In `ref.sql`, if both dev and prod relations exist and the cache contains an entry for the parent, the cached timestamps determine which relation to return.
3. **Cache miss** (e.g. `dbt compile`, dbt Power User preview, or stale cache from a long-running process): `ref.sql` falls back to a live `get_node_timestamps` call for just that one model pair.

### Dispatch pattern

All macros follow the same pattern — a thin public entry point that delegates to adapter-specific implementations:

```jinja
{% macro my_macro(args) %}
    {{ return(adapter.dispatch("my_macro", "upstream_prod")(args)) }}
{% endmacro %}

{% macro default__my_macro(args) %}...{% endmacro %}
{% macro snowflake__my_macro(args) %}...{% endmacro %}
```

## Integration Tests

Tests live in `integration_tests/`. The test runner:
1. Iterates over all project configs in `dbt_project_files/` (each tests a different schema/database setup)
2. Sets `UP_TARGET_PLATFORM` (resolved to a profile in `integration_tests/profiles.yml`)
3. Builds staging models in prod, then downstream models in dev, then asserts correct relation resolution

`dbt_project_files/` configs tested: `dev_db`, `dev_db_dev_sch`, `dev_db_env_sch`, `dev_sch`, `env_dbs`, `env_sch`.

## Running integration tests safely

`make test` runs `integration_tests/run_tests.sh`, which calls `create_test_db` for two hardcoded database names: `upproddb` and `updevdb`. This macro is **destructive** by design:

- Snowflake: `create or replace database upproddb` (drops the existing one)
- Databricks: `drop catalog if exists upproddb cascade; create catalog upproddb`
- BigQuery: drops every schema in `upproddb` and `updevdb` via `drop schema ... cascade`

Before running `make test` against your warehouse:

1. **Use a sandbox account / project** with no production data. Verify nothing important lives under the names `upproddb` or `updevdb`.
2. **Run `make debug-<platform>`** first (e.g. `make debug-bigquery`) to confirm connectivity without touching any databases.
3. **The test runner deletes everything it owns by name on each run.** This is intentional — each test config rebuilds from scratch — but unforgiving if you mis-target it.

If you only want to test a single adapter, use the platform-specific target: `make test-snowflake`, `make test-databricks`, `make test-bigquery`.

## Environment

Copy `.env.example` to `.env` and fill in credentials before running tests. Python deps managed with `uv` (`make setup`).
