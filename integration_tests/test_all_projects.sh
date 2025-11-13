# Stop the script when any errors are returned
set -e

# Change to directory the script is in
script_dir=$(dirname "$(readlink -f "$0")")
cd $script_dir

export DBT_QUIET=true

for platform in sf dbx bq
do
    export UP_TARGET_PLATFORM=$platform

    for file in dbt_project_files/*
    do
        cat $file > dbt_project.yml
        echo ""
        echo ""
        echo "#### TESTING NEW PROJECT"
        echo "#### $file ($platform)"
        sh run_tests.sh
    done
done
