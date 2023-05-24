# Setup
echo "\nSETTING UP ENVIRONMENT\n"
dbt clean
dbt deps
dbt run-operation create_test_db --args '{db: upstream__prod_db}'
dbt run-operation create_test_db --args '{db: upstream__dev_db}'

# Create staging model in appropriate envs
echo "\nBUILDING STAGING MODELS\n"
dbt build -s stg__defer_prod --target prod
dbt build -s stg__dev_fallback

# Build & test upstream models
echo "\nBUILDING UPSTREAM MODELS\n"
dbt build -s defer_prod dev_fallback