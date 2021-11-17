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

function branch () {
	branchNewHead=`git branch --show-current`

	# Evaluate current environment
	TAZ_APP_CONFIG="Alpha"

	if [[ $branchNewHead == 'beta'  ]]
	then
	  TAZ_APP_CONFIG="Beta"
	elif [[ $branchNewHead == 'release'  ]]
	then
	  TAZ_APP_CONFIG="Release"
	fi

	echo "set Icon and Scheme Config to: $1"
	setConfig $TAZ_APP_CONFIG
	echo "update Build Number"
	ruby genBuildConst.rb -D
}

function help () {
	echo "
Helper to change:
- (Bundled) AppIcon in AssetCatalog
- Selected Configuration in current (shared) Scheme for all Actions
	
Usage: (if Parameters expected, Relese is default)
refreshEnvironment.sh                                           #prints this help
refreshEnvironment.sh setSchemeEnvironment [Alpha|Beta|Release] #set scheme Environment to known scheme file
refreshEnvironment.sh setAppIcon [Alpha|Beta|Release] 		#set AppIcon
refreshEnvironment.sh setConfig [Alpha|Beta|Release] 		#set AppIcon and scheme Environment
refreshEnvironment.sh Alpha|alpha				#set AppIcon and scheme Environment to Alpha
refreshEnvironment.sh Beta|beta					#set AppIcon and scheme Environment to Beta
refreshEnvironment.sh Release|release				#set AppIcon and scheme Environment to Release
refreshEnvironment.sh -b|branch					#set AppIcon and scheme Environment depending on current branch

Used default Files and locations
SCHEME_FILE: $SCHEME_FILE
Asset Catalog Source: $ICON_SOURCE
Asset Catalog Target: $ICON_TARGET

Run this Script from current Location in: $SRCROOT/taz.neo/Supporting\ Files/Scripts
"
}

cd "$(dirname "$0")"

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
	branch) branch Release; exit;;
	-b) branch Release; exit;;
esac

help