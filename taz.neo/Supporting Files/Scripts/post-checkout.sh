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
branchNewHead=`git name-rev --name-only $newHEAD`

echo '\n ==============================================='
echo '\n  Post-checkout set scheme environment for Xcode'
echo '\n  you may want to change this in Xcode by changing:'
echo '\n  Target => Edit Scheme => (Debug|Run|Archive) Build Configuration'
echo '\n ===============================================\n\n'

# Print Info
if [[ $checkoutType != 1 ]]
then
 	echo 'No branch checkout do nothing!'
 	exit 0
fi

# Evaluate current environment
TAZ_APP_CONFIG="Debug-Alpha"

if [[ $checkoutType == 1 ]] && [[ $branchNewHead == 'beta'  ]] 
then
  TAZ_APP_CONFIG="Beta"
elif [[ $checkoutType == 1 ]] && [[ $branchNewHead == 'release'  ]] 
then
  TAZ_APP_CONFIG="Release"
fi

echo "Set Scheme Environment for branch: $branchNewHead to $TAZ_APP_CONFIG"

# change default scheme to environment
sed -i '' -e 's#buildConfiguration = ".*\"#buildConfiguration = \"'"$TAZ_APP_CONFIG"'\"#g' taz.neo.xcodeproj/xcshareddata/xcschemes/taz.neo.xcscheme