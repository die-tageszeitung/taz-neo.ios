#!/bin/bash
ALPHA_CONFIG=./../ConfigSettingsDebugAlpha.xcconfig
BETA_CONFIG=./../ConfigSettingsBeta.xcconfig
RELEASE_CONFIG=./../ConfigSettingsRelease.xcconfig

set -e
. ./LastBuildNumber.rb

applyBuildNumber() {
	sed -i '' -e "s#.*CURRENT_PROJECT_VERSION.*#CURRENT_PROJECT_VERSION = $LastBuildNumber#g" $1
}

applyBuildNumberAll() {
	applyBuildNumber $ALPHA_CONFIG
	applyBuildNumber $BETA_CONFIG
	applyBuildNumber $RELEASE_CONFIG
}

function help () {
	echo "
Apply Current Build Number from LastBuildNumber.rb
to ConfigSettings????????.xcconfig

Valid Options: Alpha|Beta|Release|all
"
}

echo "UPDATE PROJECT VERSION to $LastBuildNumber"

case $1 in
    Alpha) applyBuildNumber $ALPHA_CONFIG; exit;;
    Beta) applyBuildNumber $BETA_CONFIG; exit;;
    Release) applyBuildNumber $RELEASE_CONFIG; exit;;
    all) applyBuildNumberAll; exit;;
esac

help