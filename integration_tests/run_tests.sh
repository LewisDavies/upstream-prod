# Setup
set -e
echo ""
echo "## SETTING UP ENVIRONMENT"
echo ""
dbt clean
dbt deps
dbt run-operation create_test_db --args '{db: upstream__prod_db}'
dbt run-operation create_test_db --args '{db: upstream__dev_db}'

# Create staging models in appropriate envs
echo ""
echo "## BUILDING STAGING MODELS"
echo ""
dbt snapshot --target prod
dbt build -s stg__defer_prod stg__defer_vers stg__dev_newer stg__cross_project --target prod
dbt build -s stg__dev_fallback stg__dev_newer

# Build & test downstream models
echo ""
echo "## BUILDING DOWNSTREAM MODELS"
echo ""
dbt build -s models/marts

# Check --empty flag
echo ""
echo "## CHECKING EMPTY FLAG"
echo ""
dbt build -s defer_prod --empty

# Check dbt-codegen compatibility
echo ""
echo "## CHECKING CODEGEN OUTPUT"
echo ""
dbt run-operation generate_model_yaml --args '{"model_names": [stg__defer_prod]}'
