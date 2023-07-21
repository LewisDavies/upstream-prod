projects="dev_db dev_db_dev_sch dev_db_env_sch dev_sch env_sch"

for proj in $projects
do
    ln -f _template/packages.yml $proj
    ln -f _template/run_tests.sh $proj
    ln -f _template/macros/* $proj/macros
    ln -f _template/models/production/* $proj/models/production
    ln -f _template/models/staging/* $proj/models/staging
    ln -f _template/tests/singular_test.sql $proj/tests
done
