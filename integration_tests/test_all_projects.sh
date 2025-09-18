set -e

for platform in sf dbx bq
do
    export UP_TARGET_PLATFORM=$platform

    for file in dbt_project_files/*
    do
        cat $file > dbt_project.yml
        echo ""
        echo ""
        echo ""
        echo "#### TESTING NEW PROJECT"
        echo "#### $file"
        sh run_tests.sh
    done
done
