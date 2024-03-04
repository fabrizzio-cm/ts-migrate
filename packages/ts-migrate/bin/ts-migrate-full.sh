#!/usr/bin/env bash

set -e

frontend_folder=$1
folder_name=`basename $1`
CLI_DIR=$(dirname "$0")
cli="./node_modules/ts-migrate/build/cli.js"
step_i=1
step_count=4
tsc_path="./node_modules/typescript/bin/tsc"
should_remove_eslintrc=false
additional_args="${@:2}"


migrated_files=$(echo "$additional_args" | awk -F' ' '{print $1}' | sed 's/--sources=//')

echo "Your default tsc path is $tsc_path."


function maybe_commit() {
  cd $frontend_folder
  if [[ `git status --porcelain` ]]
  then
    git add . && git commit "$@"
  fi
  cd -
}

function commit_single_file() {
    if [ "$#" -eq 0 ]; then
        echo "No files to add."
        return
    fi
    js_file="$1"
    file_no_ext="${js_file%.*}"
    ts_file="$file_no_ext.ts"
    git add $js_file $ts_file
    echo "feat: migrate $js_file to TS"
    git commit -m "feat: migrate $js_file to TS"
}

echo "
[Step $((step_i++)) of ${step_count}] Initializing ts-config for the \"$frontend_folder\"...
"

if [ ! -f "$frontend_folder/tsconfig.json" ]; then
    echo "Creatint tsconfig HMMM"
    $cli init $frontend_folder
fi

maybe_commit -m "[ts-migrate][$folder_name] Init tsconfig.json file" -m 'Co-authored-by: ts-migrate <>'

echo "
[Step $((step_i++)) of ${step_count}] Renaming files from JS/JSX to TS/TSX and updating project.json\...
"
$cli rename $frontend_folder $additional_args

echo "
[Step $((step_i++)) of ${step_count}] Fixing TypeScript errors...
"
echo $cli migrate $frontend_folder $additional_args
$cli migrate $frontend_folder $additional_args

if [ "$should_remove_eslintrc" = "true" ]; then
  rm -f $frontend_folder/.eslintrc
fi

deleted_files=$(git status --porcelain | awk '$1 == "D" {print $2}')

# Read each line into an array
while IFS= read -r line; do
  deleted_files_array+=("$line")
done <<< "$deleted_files"

# Print each deleted file name
echo "Deleted files:"
for file in "${deleted_files_array[@]}"; do
  commit_single_file $file
done

exit 0

echo "
[Step $((step_i++)) of ${step_count}] Checking for TS compilation errors (there shouldn't be any).
"
echo "$tsc_path -p $frontend_folder/tsconfig.json"
$tsc_path -p $frontend_folder/tsconfig.json --noEmit

echo "
---
All done!

The recommended next steps are...

1. Sanity check your changes locally by inspecting the commits and loading the affected pages.

2. Push your changes with \`git push\`.

3. Open a PR!
"