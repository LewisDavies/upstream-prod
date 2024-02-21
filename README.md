# What is upstream-prod?

`upstream-prod` is a dbt package for easily using production data in a development environment. It's an alternative to the [defer flag](https://docs.getdbt.com/reference/node-selection/defer) - only without the need to find and download a production manifest.

It is inspired by (but unrelated to) [similar work by Monzo](https://monzo.com/blog/2021/10/14/an-introduction-to-monzos-data-stack).

> #### ⚠️ Setup instructions changed in version `0.5.0` - make sure to review them if updating from an earlier version.

## How it works
I would often get errors when developing locally because my dev database had outdated or missing data. Rebuilding models was often time-consuming and it wasn't easy to tell how many layers deep I needed to go.

`upstream-prod` fixes this by overriding the `{{ ref() }}` macro, redirecting `ref`s in selected models & tests to their equivalent relations in your production environment.

For example, with a simple DAG:
```
model_1 -> model_2 -> model_3
```
And `profiles.yml`:
```yml
jaffle_shop:
  target: dev
  outputs:
    dev:
      ...
    prod:
      ...
```
When `dbt build -s model_2+` is run:
- `dev.model_2` is built using data from `prod.model_1`.
- `dev.model_3` is built on top of `dev.model_2`.
- Tests are run against the `dev.model_2` and `dev.model_3`.

> For tests that refer to multipe tables, such as relationship tests, the `prod` version of the comparison model will be used when available.

The selected models are now available in your development environment with production-quality data. The package can optionally return a `dev` model when the `prod` version can't be found. This is useful when adding several new models at once.

## Setup

### 1. Required variables

Add the relevant variables to `dbt_project.yml`. This varies depending on how your project is configured. The examples below should help you identify your project setup:

| Setup                                                                                                           | Prod examples                               | Dev examples                                            |
|-----------------------------------------------------------------------------------------------------------------|---------------------------------------------|---------------------------------------------------------|
| Dev databases                                                                                                   | `db.prod.table`</br>`db.prod_stg.stg_table` | `dev_db.prod.table`</br>`dev_db.prod_stg.stg_table`     |
| Custom schemas ([docs](https://docs.getdbt.com/docs/build/custom-schemas#what-is-a-custom-schema))              | `db.prod.table`</br>`db.prod_stg.stg_table` | `db.dbt_<name>.table`</br>`db.dbt_<name>_stg.stg_table` |
| Env schemas ([docs](https://docs.getdbt.com/docs/build/custom-schemas#advanced-custom-schema-configuration))    | `db.prod.table`</br>`db.stg.stg_table`      | `db.dbt_<name>.table`</br>`db.dbt_<name>.stg_table`     |

Open `profiles.yml` and find the relevant details for your setup:
- **Dev databases**: set `upstream_prod_database` to the `database` value of your `prod` target.
- **Custom schemas**: set `upstream_prod_schema` to the `schema` value of your `prod` target.
- **Env schemas**: set `upstream_prod_env_schemas` to `True`.

When using env schemas, you also need to add the `is_upstream_prod` parameter to your `generate_schema_name` macro:
```sql
-- is_upstream_prod should default to False
{% macro generate_schema_name(custom_schema_name, node, is_upstream_prod=False) -%}
    {%- set default_schema = target.schema -%}
    -- Add the parameter to the clause that generates your prod schema names, making sure to 
    -- enclose the *or* condition in brackets 
    {%- if (target.name == "prod" or is_upstream_prod == true) and custom_schema_name is not none -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ default_schema }}
    {%- endif -%}
{%- endmacro %}
```

> These options can be combined. For example, if you use dev databases and env schemas you would set both `upstream_prod_database` and `upstream_prod_env_schemas`.

### 2. Optional variables
- `upstream_prod_enabled`: Disables the package when False. Defaults to True.
- `upstream_prod_disabled_targets`: List of targets where the package should be disabled.
- `upstream_prod_fallback`: Whether to fall back to the default target when a model can't be found in prod. Defaults to False.
- `upstream_prod_prefer_recent`: Whether to use dev relations that were updated more recently than prod; particularly useful when working on multiple large / slow models at once. Only supported in Snowflake & BigQuery. Defaults to False.

**Example**

I use Snowflake and each developer has a separate database with identically-named schemas. This is how my project is configured:

```yml
# dbt_project.yml
vars:
  upstream_prod_database: <prod_db> # replace with your prod db
  upstream_prod_fallback: True
  upstream_prod_prefer_recent: True
  upstream_prod_disabled_targets:
    - ci
    - prod
```

The integration tests provide examples for all supported setups:
- [Dev databases](https://github.com/LewisDavies/upstream-prod/tree/main/integration_tests/dev_db/dbt_project.yml)
- [Custom schemas](https://github.com/LewisDavies/upstream-prod/tree/main/integration_tests/dev_sch/dbt_project.yml)
- [Env schemas](https://github.com/LewisDavies/upstream-prod/tree/main/integration_tests/env_sch/dbt_project.yml)
- [Dev databases & custom schemas](https://github.com/LewisDavies/upstream-prod/tree/main/integration_tests/dev_db_dev_sch/dbt_project.yml)
- [Dev databases & env schemas](https://github.com/LewisDavies/upstream-prod/tree/main/integration_tests/dev_db_env_sch/dbt_project.yml)

### 3. Update `ref()`
dbt needs to use this package's version of `{{ ref() }}` instead of the builtin macro. The recommended approach is to create a thin wrapper around `upstream-prod`.

In your `macros` directory, create a file called `ref.sql` with the following contents:
```python
{% macro ref(
    parent_model, 
    prod_database=var("upstream_prod_database", None), 
    prod_schema=var("upstream_prod_schema", None),
    enabled=var("upstream_prod_enabled", True),
    fallback=var("upstream_prod_fallback", False),
    env_schemas=var("upstream_prod_env_schemas", False),
    version=None,
    prefer_recent=var("upstream_prod_prefer_recent", False),
    prod_database_replace=var("upstream_prod_database_replace", None)
) %}

    {% do return(upstream_prod.ref(
        parent_model, 
        prod_database, 
        prod_schema, 
        enabled, 
        fallback, 
        env_schemas, 
        version, 
        prefer_recent,
        prod_database_replace
    )) %}

{% endmacro %}
```

Alternatively, you can find any instances of `{{ ref() }}` in your project and replace them with `{{ upstream_prod.ref() }}`.

## Compatibility
`upstream-prod` can be used on: 
- Snowflake
- BigQuery
- Redshift ([RA3 nodes](https://aws.amazon.com/redshift/features/ra3/) are required to query across databases)
- Databricks

It should also work with community-supported adapters that specify a target database and schema - PRs are welcome if it doesn't!
