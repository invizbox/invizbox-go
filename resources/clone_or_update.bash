#!/usr/bin/env bash

set -e
set -u

folder=$1
# explicit SHA below to force a rebuild from BUCK and fail cache lookup
commit_SHA="ab57d95a176f2a868310c0802fc49558d2179cd3"
repository="https://github.com/invizbox/lede.git"

if [ -d ${folder} ]; then
    echo "A ${folder} repository already exists, checking if it is the correct one"
    cd ${folder}
    local_repo=$(git remote -v | grep origin | grep fetch | awk '{print $2}')
    if [ ${repository} == ${local_repo} ]; then
        echo "The repo is the correct one, updating it"
        git fetch --all -p
        git checkout --force ${commit_SHA} 2>/dev/null
        exit 0
    else
        echo "The repo wasn't the correct one. Expected [${repository}] but got [${local_repo}] removing it"
        cd ..
        rm -rf ${folder}
    fi
fi
# now we either removed a repo that wasn't the correct one or none existed.
echo "Cloning ${repository}"
git clone ${repository} ${folder} 2>/dev/null
cd ${folder}
git checkout ${commit_SHA} 2>/dev/null
echo "Successful update/clone of repo ${repository}"
