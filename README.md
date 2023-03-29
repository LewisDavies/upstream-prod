# What is upstream-prod?

`upstream-prod` is a dbt package for easily using production data in a development environment. It's like an alternative to the [defer flag](https://docs.getdbt.com/reference/node-selection/defer) - only without the need to find and download a production manifest.

It is inspired by (but unrelated to) [similar work by Monzo](https://monzo.com/blog/2021/10/14/an-introduction-to-monzos-data-stack).

## How it works
When developing locally, I would often get errors because my dev database had outdated or missing data. Rebuilding the models was often time-consuming and it wasn't easy to tell how many layers deep I needed to go.

`upstream-prod` fixes this by overriding the `{{ ref() }}` macro, redirecting `ref`s in selected models & tests to their equivalent relations in your production environment.

For example, imagine a simple DAG like:
```
model_1 -> model_2 -> model_3
```
With a `profiles.yml` similar to:
```yml
jaffle_shop:
  target: dev
  outputs:
    dev:
      ...
    prod:
      ...
```
If I run `dbt build -s model_2+`, the following happens:
- `model_2` is built in `dev` with data from the `prod` version of `model_1`.
- `model_3` is also built in `dev` but it refers to the `dev` version of `model_2`.
- Tests are run against the `dev` versions of `model_2` and `model_3`.

> For tests that refer to multipe tables, such as relationship tests, the `prod` version of the comparison model will be used when available.

In short, your selected models are available in your `dev` environment with all that lovely `prod` quality!

### Optional: default target fallback
If desired, the package can return a `dev` model when the `prod` version can't be found. This is useful when adding several new models at once.

Let's assume only `model_1` is in `prod` and I want to create `model_2` and `model_3`. First I create `model_2` in `dev` with `dbt run -s model_2`, then start working on `model_3`. By default, `dbt run -s model_3` would fail because `model_2` doesn't exist in `prod`. With fallback mode enabled, the package would use the `dev` model and the command would be successful.

## Setup

### 1. Required variables

After installing the package, you need to add some variables to `dbt_project.yml` so it knows where to find production data. This varies depending on how your project is configured.

| Setup                                                                                                     | Prod examples                               | Dev examples                                            |
|-----------------------------------------------------------------------------------------------------------|---------------------------------------------|---------------------------------------------------------|
| Custom schemas ([examples](https://docs.getdbt.com/docs/build/custom-schemas#what-is-a-custom-schema))    | `db.prod.table`</br>`db.prod_stg.stg_table` | `db.dbt_<name>.table`</br>`db.dbt_<name>_stg.stg_table` |
| Custom env schemas ([example](https://docs.getdbt.com/docs/build/custom-schemas#what-is-a-custom-schema)) | `db.prod.table`</br>`db.stg.stg_table`      | `db.dbt_<name>.table`</br>`db.dbt_<name>.stg_table`     |
| Dev databases                                                                                             | `db.prod.table`</br>`db.prod_stg.stg_table` | `dev_db.prod.table`</br>`dev_db.prod_stg.stg_table`     |

Open `profiles.yml` and find the relevant details for your setup:
- **Custom schemas**: set `upstream_prod_schema` to the `schema` value of your `prod` target.
- **Custom env schemas**: same as above, but also set the variable `upstream_prod_env_schemas` to `True`.
- **Dev databases**: set `upstream_prod_database` to the `database` value of your `prod` target.

### 2. Optional variables
- `upstream_prod_enabled`: Disables the package when False. Defaults to True.
- `upstream_prod_disabled_targets`: List of targets where the package should be disabled.
- `upstream_prod_fallback`: Whether to fall back to the default target when a model can't be found in prod. Defaults to False.

**Example**

I use Snowflake and each developer has a separate database with identically-named schemas. Here's how I have configured my project:

```yml
# dbt_project.yml
vars:
  upstream_prod_database: <prod_db> # replace with your prod db
  upstream_prod_fallback: True
  upstream_prod_disabled_targets:
    - ci
    - prod
```

### 3. Update `ref()`
Next, you need to tell dbt to use this package's version of `{{ ref() }}` instead of the builtin macro. The recommended approach is to create a thin wrapper around `upstream-prod`. In your `macros` directory, create a file called `ref.sql` with the following contents:
```python
{% macro ref(
    parent_model, 
    current_model=this.name, 
    prod_database=var("upstream_prod_database", None), 
    prod_schema=var("upstream_prod_schema", None),
    enabled=var("upstream_prod_enabled", True),
    fallback=var("upstream_prod_fallback", False),
    env_schemas=var("upstream_prod_env_schemas", False)
) %}

  {% do return(upstream_prod.ref(parent_model, current_model, prod_database, prod_schema, enabled, fallback, env_schemas)) %}

{% endmacro %}
```

Alternatively, you can find any instances of `{{ ref() }}` in your project and replace them with `{{ upstream_prod.ref() }}`.

## Compatibility
`upstream-prod` has been designed and tested on Snowflake. User reports indicate that it works perfectly with BigQuery and Redshift, and it should also work with most community-supported adapters - PRs are welcome if it doesn't!
