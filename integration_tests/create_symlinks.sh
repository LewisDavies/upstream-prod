projects="dev_db dev_db_replace dev_db_dev_sch dev_db_env_sch dev_sch env_sch"

for proj in $projects
do
    mkdir -p $proj/macros
    mkdir -p $proj/models/marts
    mkdir -p $proj/models/staging
    mkdir -p $proj/tests
    ln -f _template/packages.yml $proj
    ln -f _template/run_tests.sh $proj
    ln -f _template/macros/* $proj/macros
    ln -f _template/models/marts/* $proj/models/marts
    ln -f _template/models/staging/* $proj/models/staging
    ln -f _template/tests/* $proj/tests
done
