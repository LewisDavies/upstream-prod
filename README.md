# What is upstream-prod?

`upstream-prod` is a dbt package for easily using production data in a development environment. It's like an alternative to the [defer flag](https://docs.getdbt.com/reference/node-selection/defer) - only without the need to find and download a production manifest.

It is inspired by (but unrelated to) [similar work by Monzo](https://monzo.com/blog/2021/10/14/an-introduction-to-monzos-data-stack).

## How it works
When developing locally, I would often get errors because my dev database had outdated or missing data. Rebuilding the models was often time-consuming and it wasn't easy to tell how many layers deep I needed to go.

`upstream-prod` fixes this by overriding the `{{ ref() }}` macro, redirecting `ref`s in selected models to their equivalent table in production (unless the parent model was also selected).

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
- `model_3` is also built in my `dev` but it refers to the `dev` version of `model_2`.
- Tests are run against the `dev` versions of `model_2` and `model_3`.

In short, your selected models are available in your `dev` environment with all that lovely `prod` quality!

## Setup

### 1. Required variables

After installing the package you'll need to add some variables to `dbt_project.yml`.

Set either of `upstream_prod_schema` or `upstream_prod_database` to tell the package where to find production data. Open `profiles.yml` and set the relevant variables for your setup:

- If dev and prod are in **different schemas in the same database**, set `upstream_prod_schema` to the `schema` value of your prod target.
- If dev and prod are in **different logical databases**, set `upstream_prod_database` to the `database` value of your prod target.

### 2. Optional variables
- `upstream_prod_enabled`: Disables the package when False. Defaults to True.
- `upstream_prod_fallback`: When True, models will use the default target when a prod version doesn't exist (useful when changing multiple tables at once). Defaults to False.
- `upstream_prod_disabled_targets`: List of targets where the package should be disabled.

**Example**

I use Snowflake and each developer has a separate database with identically-named schemas. Here's how I have configured my project:

```yml
# dbt_project.yml
vars:
  upstream_prod_database: <prod_db>
  upstream_prod_fallack: True
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
    fallback=var("upstream_prod_fallback", False)
) %}

  {% do return(upstream_prod.ref(parent_model, current_model, prod_database, prod_schema, enabled, fallback)) %}

{% endmacro %}
```

Alternatively, you can find any instances of `{{ ref() }}` in your project and replace them with `{{ upstream_prod.ref() }}`

## Compatibility
`upstream-prod` has been designed and tested on Snowflake only. It _should_ work with other officially supported adapters but I can't be sure. If it doesn't, PRs are welcome!
