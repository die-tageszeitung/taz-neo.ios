#!/bin/bash

SCHEME_FILE=../../../taz.neo.xcodeproj/xcshareddata/xcschemes/taz.neo.xcscheme
ICON_SOURCE=../AppIcons
ICON_TARGET=../Assets.xcassets/AppIcon.appiconset/

function setSelectedSchemeConfiguration () {
	SELECTED_CONFIG="Release"
	if [[ $1 == 'Alpha'  ]]
	then
	  SELECTED_CONFIG="Debug"
	elif [[ $1 == 'Beta'  ]] 
	then
	  SELECTED_CONFIG="Beta"
	fi
	
	echo "Set selected Scheme Configuration: $SELECTED_CONFIG for all Actions!"
	echo "Warning: If Xcode is opened a change has probably no effect on Run Action"
	echo "Warning: A change may require a clean build!"
	# change default scheme to environment
	sed -i '' -e 's#buildConfiguration = ".*\"#buildConfiguration = \"'"$SELECTED_CONFIG"'\"#g' $SCHEME_FILE
}

function setAppIcon () {
	echo "setAppIcon for $1"

	if [[ $1 == 'Alpha'  ]]
	then
	  cp -R $ICON_SOURCE/alpha/AppIcon.appiconset/ $ICON_TARGET
	elif [[ $1 == 'Beta'  ]] 
	then
	  cp -R $ICON_SOURCE/beta/AppIcon.appiconset/ $ICON_TARGET
	else
	  cp -R $ICON_SOURCE/release/AppIcon.appiconset/ $ICON_TARGET
	fi
}

function setConfig () {
	echo "set Icon and Scheme Config to: $1"
	setSelectedSchemeConfiguration $1
	setAppIcon $1
	echo "done"
}

function help () {
	echo "
Depending on passed Parameter (Configuration: Alpha|Beta|Release)

Changes Xcode projects Scheme file build configuration in
$SCHEME_FILE
with 'setSchemeEnvironment'

Copy App Icon to Asset Catalog 
from $ICON_SOURCE
to $ICON_TARGET
with 'setAppIcon'

Do both with
with 'setConfig'

If no Configuration is passed 'Release' Configuration is used
Run this Script from current Location in: $SRCROOT/taz.neo/Supporting\ Files/Scripts

Usage
====
/changeConfiguration.sh setConfig alpha
Default Action is setConfig so
short: /changeConfiguration.sh alpha|Beta|Release
"
}

case $1 in
    setSchemeEnvironment) "$@"; exit;;
    setAppIcon) "$@"; exit;;
    setConfig) "$@"; exit;;
    Alpha) setConfig Alpha; exit;;
    alpha) setConfig Alpha; exit;;
    Beta) setConfig Beta; exit;;
    beta) setConfig Beta; exit;;
    Release) setConfig Release; exit;;
	release) setConfig Release; exit;;
esac

help