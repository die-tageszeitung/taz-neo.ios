#!/bin/bash

set -e

# This is a post-checkout Helper (hook) to set Xcodes Scheme Environement depending on current branch.
# post-checkout hooks will be executed on: clone|checkout|switch 
# action will be also executed if action triggered by UI Tools like SourceTree
# 
# In project root folder run these commands:
# > [optional] mkdir .git/hooks
# > cp taz.neo/Supporting\ Files/Scripts/post-checkout.sh .git/hooks/post-checkout
# > chmod u+x .git/hooks/post-checkout
# 
# for more information:
# @see: https://git-scm.com/docs/githooks#_post_checkout
# @see: https://stackoverflow.com/a/20892987

# Assign passed Params
prevHEAD=$1
newHEAD=$2
checkoutType=$3
branchNewHead=`git branch --show-current $newHEAD`

echo 'PC :: THIS IS A POST CHECKOUT SCRIPT'

# Print Info
if [[ $checkoutType != 1 ]]
then
 	echo 'PC :: No branch checkout do nothing!'
 	exit 0
fi

# Evaluate current environment
TAZ_APP_CONFIG="Alpha"

if [[ $branchNewHead == 'beta'  ]]
then
  TAZ_APP_CONFIG="Beta"
elif [[ $branchNewHead == 'release'  ]]
then
  TAZ_APP_CONFIG="Release"
fi

cd taz.neo/Supporting\ Files/Scripts/
echo "PC :: Use changeConfiguration Script to set $TAZ_APP_CONFIG to selected Scheme config for all Actions and App Icon"
./changeConfiguration.sh $TAZ_APP_CONFIG
