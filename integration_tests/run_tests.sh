set -e

# Change to directory the script is in
script_dir=$(dirname "$(readlink -f "$0")")
cd $script_dir

# Map platform codes to display names
platform_name() {
    case $1 in
        sf)  echo "Snowflake" ;;
        dbx) echo "Databricks" ;;
        bq)  echo "BigQuery" ;;
    esac
}

# Default to all platforms; allow a single platform as an argument
if [ -n "$1" ]; then
    platforms="$1"
else
    platforms="sf dbx bq"
fi

for platform in $platforms
do
    echo ""
    echo "========================================"
    echo "  Platform: $(platform_name $platform)"
    echo "========================================"

    export UP_TARGET_PLATFORM=$platform

    for file in dbt_project_files/*
    do
        cp $file dbt_project.yml
        project=$(basename $file .yml)
        start=$SECONDS

        echo ""
        echo "  Project: $project"

        echo "    Setting up..."
        dbt clean -t dev
        dbt deps -t dev
        dbt run-operation create_test_db -t dev --args '{db: upproddb}'
        dbt run-operation create_test_db -t dev --args '{db: updevdb}'

        echo "    Running staging models..."
        dbt snapshot -t prod
        dbt run -t prod -s stg__defer_prod stg__defer_vers stg__dev_newer stg__cross_project stg__microbatch
        dbt run -t dev -s stg__dev_fallback stg__dev_newer

        echo "    Building downstream models..."
        # event-time flags only affect the microbatch model
        dbt build -t dev -s models/marts --event-time-start "2025-01-01" --event-time-end "2025-01-03"

        echo "    Checking --empty flag..."
        dbt build -t dev -s defer_prod --empty

        echo "    Checking --inline flag..."
        dbt show -t dev --inline 'select * from {{ ref("stg__dev_newer") }}' --limit 5 > /dev/null

        echo "    Checking codegen output..."
        dbt run-operation generate_model_yaml -t dev --args '{"model_names": [stg__defer_prod]}' > /dev/null

        echo "  Done in $((SECONDS - start))s"
    done
done
