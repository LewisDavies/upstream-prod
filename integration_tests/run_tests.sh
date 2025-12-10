# Setup
set -e
echo ""
echo "## SETTING UP ENVIRONMENT"
dbt clean
dbt deps
dbt run-operation create_test_db --args '{db: upproddb}'
dbt run-operation create_test_db --args '{db: updevdb}'

# Create staging models in appropriate envs
echo ""
echo "## RUNNING STAGING MODELS"
dbt snapshot -t prod
dbt run -s stg__defer_prod stg__defer_vers stg__dev_newer stg__cross_project stg__microbatch -t prod
dbt run -s stg__dev_fallback stg__dev_newer

# Build & test downstream models
echo ""
echo "## BUILDING DOWNSTREAM MODELS"
# event-time flags only affect the microbatch model
dbt build -s models/marts --event-time-start "2025-01-01" --event-time-end "2025-01-03"

# Check --empty flag
echo ""
echo "## CHECKING EMPTY FLAG"
dbt build -s defer_prod --empty

# Check dbt-codegen compatibility
echo ""
echo "## CHECKING CODEGEN OUTPUT"
dbt run-operation generate_model_yaml --args '{"model_names": [stg__defer_prod]}'
