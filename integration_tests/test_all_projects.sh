set -e
projects="dev_db dev_db_replace dev_db_dev_sch dev_db_env_sch dev_sch env_sch"
tests_dir=$(pwd)

for proj in $projects
do
    # Create project directory
    mkdir -p $proj/macros
    mkdir -p $proj/models/marts
    mkdir -p $proj/models/staging
    mkdir -p $proj/snapshots
    mkdir -p $proj/tests
    # Symlink template files to test project
    ln -f _template/packages.yml $proj
    ln -f _template/run_tests.sh $proj
    ln -f _template/macros/* $proj/macros
    ln -f _template/models/marts/* $proj/models/marts
    ln -f _template/models/staging/* $proj/models/staging
    ln -f _template/snapshots/* $proj/snapshots
    ln -f _template/tests/* $proj/tests
    # Run test project
    cd $tests_dir/$proj
    echo ""
    echo ""
    echo ""
    echo "#### TESTING NEW PROJECT"
    echo "#### $proj"
    sh run_tests.sh
    cd $tests_dir
done
