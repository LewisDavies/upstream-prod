# Stop the script when any errors are returned
set -e

# Change to directory the script is in
script_dir=$(dirname "$(readlink -f "$0")")
cd $script_dir

for platform in bq dbx sf
do
    export UP_TARGET_PLATFORM=$platform
    echo ""
    echo ""
    date
    echo "#### TESTING ALL PROJECTS ($platform)"
    sh run_tests.sh
done
