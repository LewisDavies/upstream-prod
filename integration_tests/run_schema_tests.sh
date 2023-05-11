# Setup
echo "Setting up environment"
dbt clean
dbt deps
dbt run-operation create_test_db --args '{db: upstream__prod_db}'
dbt run-operation create_test_db --args '{db: upstream__dev_db}'

# Test fallback option
echo "\nTesting dev fallback option\n"
dbt run -s stg__dev_fallback --vars '{upstream_prod_schema: prod}' --target dev
dbt build -s dev_fallback --vars '{upstream_prod_schema: prod, upstream_prod_fallback: true}' --target dev

# Test deferral to prod
echo "\nTesting prod deferral\n"
dbt run -s stg__defer_prod --vars '{upstream_prod_schema: prod}' --target prod
dbt build -s defer_prod --vars '{upstream_prod_schema: prod}' --target dev