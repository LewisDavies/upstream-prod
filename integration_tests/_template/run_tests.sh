# Setup
set -e
echo "\nSETTING UP ENVIRONMENT\n"
dbt clean
dbt deps
dbt run-operation create_test_db --args '{db: upstream__prod_db}'
dbt run-operation create_test_db --args '{db: upstream__dev_db}'

# Create staging model in appropriate envs
echo "\nBUILDING STAGING MODELS\n"
dbt build -s stg__defer_prod stg__defer_vers stg__dev_newer --target prod
dbt build -s stg__dev_fallback stg__dev_newer

# Build & test downstream models
echo "\nBUILDING DOWNSTREAM MODELS\n"
dbt build -s models/marts

# Check dbt-codegen compatibility
dbt run-operation generate_model_yaml --args '{"model_names": [stg__defer_prod]}'
