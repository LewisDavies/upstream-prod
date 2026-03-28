-include .env
export
export DBT_PROJECT_DIR=$(CURDIR)/integration_tests
export DBT_PROFILES_DIR=$(CURDIR)/integration_tests

.PHONY: setup test-snowflake test-databricks test-bigquery test debug-snowflake debug-databricks debug-bigquery debug

# Setup
setup: .venv .env

.venv:
	@command -v uv > /dev/null || { echo "Error: uv is required. Install it from https://docs.astral.sh/uv/"; exit 1; }
	uv sync

.env:
	cp .env.example .env
	@echo "Created .env - add your credentials then run 'make debug' or 'make test'"

# Debug
debug: debug-snowflake debug-databricks debug-bigquery

debug-snowflake:
	cp integration_tests/dbt_project_files/dev_db.yml integration_tests/dbt_project.yml
	UP_TARGET_PLATFORM=sf dbt debug

debug-databricks:
	cp integration_tests/dbt_project_files/dev_db.yml integration_tests/dbt_project.yml
	UP_TARGET_PLATFORM=dbx dbt debug

debug-bigquery:
	cp integration_tests/dbt_project_files/dev_db.yml integration_tests/dbt_project.yml
	UP_TARGET_PLATFORM=bq dbt debug

# Tests
test: test-snowflake test-databricks test-bigquery

test-snowflake:
	@UP_TARGET_PLATFORM=sf DBT_QUIET=true sh integration_tests/run_tests.sh

test-databricks:
	@UP_TARGET_PLATFORM=dbx DBT_QUIET=true sh integration_tests/run_tests.sh

test-bigquery:
	@UP_TARGET_PLATFORM=bq DBT_QUIET=true sh integration_tests/run_tests.sh
