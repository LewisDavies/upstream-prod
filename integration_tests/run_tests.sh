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

# Report which dbt is on PATH so the user knows whether they're testing core or fusion
dbt_version=$(dbt --version 2>&1)
case "$dbt_version" in
    *[Ff]usion*) dbt_flavor="dbt-fusion" ;;
    *[Cc]ore*)   dbt_flavor="dbt-core" ;;
    *)
        echo "Error: could not determine dbt flavor from 'dbt --version':" >&2
        echo "$dbt_version" >&2
        exit 1
        ;;
esac

for platform in $platforms
do
    echo ""
    echo "========================================"
    echo "  Platform: $(platform_name $platform) ($dbt_flavor)"
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

        echo "    Seeding test seeds..."
        dbt seed -t prod -s seed__defer_prod seed__dev_newer
        dbt seed -t dev -s seed__dev_newer

        echo "    Running staging models..."
        dbt snapshot -t prod
        dbt run -t prod -s stg__aliased stg__defer_prod stg__defer_vers stg__dev_newer stg__cross_project stg__microbatch stg__sample_flag
        dbt run -t dev -s stg__dev_fallback stg__dev_newer

        # microbatch builds crash inside dbt-databricks / dbt-bigquery Fusion
        # materializations (see README "Known limitations"). Reproduces without
        # upstream-prod, so we exclude it from all Fusion runs.
        # sample_flag is built separately below since it requires --sample.
        excludes="sample_flag"
        if [ "$dbt_flavor" = "dbt-fusion" ]; then
            excludes="$excludes config.incremental_strategy:microbatch"
        fi

        echo "    Building downstream models..."
        # event-time flags only affect the microbatch model
        dbt build -t dev -s models/marts --exclude "$excludes" --event-time-start "2025-01-01" --event-time-end "2025-01-03"

        echo "    Checking --empty flag..."
        dbt build -t dev -s defer_prod --empty

        echo "    Checking --sample flag..."
        dbt build -t dev -s sample_flag --sample='3 days'

        echo "    Checking --inline flag..."
        dbt show -t dev --inline 'select * from {{ ref("stg__dev_newer") }}' --limit 5 > /dev/null

        echo "    Checking codegen output..."
        dbt run-operation generate_model_yaml -t dev --args '{"model_names": [stg__defer_prod]}' > /dev/null

        echo "  Done in $((SECONDS - start))s"
    done
done
