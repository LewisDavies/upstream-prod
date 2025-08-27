set -e

for file in dbt_project_files/*
do
    cat $file > dbt_project.yml
    echo ""
    echo ""
    echo ""
    echo "#### TESTING NEW PROJECT"
    echo "#### $file"
    sh run_tests.sh
    rm dbt_project.yml
done
