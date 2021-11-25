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
  echo "warning remove this will be done by ruby soon!"
  changeBuildConst $1
  cleanXcodeCache
	echo "done"
}

#Shortcut for Tests
function changeBuildConst () {
  XCCONFIG=../ConfigSettings.xcconfig
  BUILDCONST=BuildConst.swift
  echo "changeBuildConst $1 to: $XCCONFIG AND $BUILDCONST"
  
  if [[ $1 == 'Alpha'  ]]
  then
    sed -i '' -e 's#PRODUCT_NAME.*#PRODUCT_NAME = taz.alpha#g' $XCCONFIG
    sed -i '' -e 's#PRODUCT_BUNDLE_IDENTIFIER.*#PRODUCT_BUNDLE_IDENTIFIER = de.taz.taz.neo#g' $XCCONFIG
    sed -i '' -e 's#static var name.*#  static var name: String { \"'"taz.alpha"'\" }#g' $BUILDCONST
    sed -i '' -e 's#static var id.*#  static var id: String { \"'"de.taz.taz.neo"'\" }#g' $BUILDCONST
    sed -i '' -e 's#static var state.*#  static var state: String { \"'"alpha"'\" }#g' $BUILDCONST
  elif [[ $1 == 'Beta'  ]]
  then
    sed -i '' -e 's#PRODUCT_NAME.*#PRODUCT_NAME = taz.beta#g' $XCCONFIG
    sed -i '' -e 's#PRODUCT_BUNDLE_IDENTIFIER.*#PRODUCT_BUNDLE_IDENTIFIER = de.taz.taz.beta#g' $XCCONFIG
    sed -i '' -e 's#static var name.*#  static var name: String { \"'"taz.beta"'\" }#g' $BUILDCONST
    sed -i '' -e 's#static var id.*#  static var id: String { \"'"de.taz.taz.beta"'\" }#g' $BUILDCONST
    sed -i '' -e 's#static var state.*#  static var state: String { \"'"beta"'\" }#g' $BUILDCONST
  else
    sed -i '' -e 's#PRODUCT_NAME.*#PRODUCT_NAME = die tageszeitung#g' $XCCONFIG
    sed -i '' -e 's#PRODUCT_BUNDLE_IDENTIFIER.*#PRODUCT_BUNDLE_IDENTIFIER = de.taz.taz.2#g' $XCCONFIG
    sed -i '' -e 's#static var name.*#  static var name: String { \"'"die tageszeitung"'\" }#g' $BUILDCONST
    sed -i '' -e 's#static var id.*#  static var id: String { \"'"de.taz.taz.2"'\" }#g' $BUILDCONST
    sed -i '' -e 's#static var state.*#  static var state: String { \"'"release"'\" }#g' $BUILDCONST
  fi
  echo "done"
}

function cleanXcodeCache () {
  echo "cleanXcodeCache"
  rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex
  rm -rf ~/Library/Developer/Xcode/DerivedData/taz.neo*
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

	echo "set Icon and Scheme Config to: $TAZ_APP_CONFIG"
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
	branch) branch; exit;;
	-b) branch; exit;;
esac

help
