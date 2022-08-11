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
After installing the package, setup is a two-step process:
1. Replace any instances of `{{ ref() }}` in your project with `{{ upstream_prod.ref() }}`
1. Specify your production database and schema in `dbt_project.yml`

```yml
# Example dbt_project.yml
vars:
  # These should match the prod target from profiles.yml
  upstream_prod_database: <prod_db>
  upstream_prod_schema: <prod_schema>
  # Optional variables
  upstream_prod_enabled: True  # Set as False to disable the package
  upstream_prod_disabled_targets:  # List of targets where upstream_prod should be disabled
    - ci
    - prod
```

## Compatibility
`upstream-prod` has been designed and tested on Snowflake only. It _should_ work with other officially supported adapted but I can't be sure. If it doesn't, PRs are welcome!
