#!/bin/sh

# This Script contain Functions to Download resources (json, zip) and unpack zip
#
# Idea: 
# On "Clean+Build" 
# 1. Script Checks if resources.json exist and is newer than 1d (YES => 2. // NO => 1a)
# 1a. Curl ressources.json from GraphQL
# 2. Check if zip exist and scroll.css Resource Version match with Version from Step 1
#    (YES => DONE // NO => 3.)
# 3a. Download Resources.zip from Server
#  b. unpack zip
#  c. compare versions (YES => DONE)
#
# In any Case of error the script aborts, and shows the error in std. out
# additionally a MacOS Notification will be shown
#
# In case of error and required build make a early exit e.g. by uncomment the following line
# exit 0
#
# Enable this script by adding the following line to 
# TARGET => RUN Script, move it to topmost position
# source .${SRCROOT}/taz.neo/Supporting\ Files/Scripts/addResources.sh
#

function bashDebug(){
	clear
	BUILT_PRODUCTS_DIR="/Users/taz/Library/Developer/Xcode/DerivedData/taz.neo-evhhpiwabilulthhegmldjnwettz/Build/Products/Debug-iphonesimulator"
	SRCROOT="/Users/taz/src/TAZ/taz-neo.ios"
	echo "BUILT_PRODUCTS_DIR: ${BUILT_PRODUCTS_DIR}"
	echo "SRCROOT: ${SRCROOT}"
}

#bashDebug # uncomment for xcode build

# Files and folders
build_jsonFile="${BUILT_PRODUCTS_DIR}/resources.json" #temporary json to download json on each clean+build
src_jsonFile="${SRCROOT}/taz.neo/Supporting Files/Resources/resources.json" # json for bundled ressources
src_files="${SRCROOT}/taz.neo/Supporting Files/Resources/files" # unpacked ressources
temp_folder="${SRCROOT}/taz.neo/Supporting Files/Resources/temp" # temporary files

# show notification if last command failed, param $1 is the line where the error occured
function check(){
	if [ ! $? -eq 0 ]; then
		command=$(cat "${BASH_SOURCE[0]}" | head -"${BASH_LINENO[0]}" | tail -1)
		calledFunction=${FUNCNAME[1]}
		echo "ERROR :: An error occured in Line: ${BASH_LINENO[0]} while Calling Command: \"${command}\" in: ${calledFunction}"
		show_notification "An error occured in Line: ${BASH_LINENO[0]}\nin: ${calledFunction}"
		exit 1 #Abort, show Error
#	else 
#		echo "## check succeeed with status $?"
	fi
}

# show notification center message optional params: $1 message; $2 title; $3 subtitle
function show_notification() {
	local title="Build Script failed"
	local subtitle="XCode Prebuild Error"
	local message="Ensure resources are available!"
	
	if [ "$1" ]; then
	  message=$1
	fi
	
	if [ "$2" ]; then
	  title=$2
	fi
	
	if [ "$3" ]; then
	  subtitle=$3
	fi
	
	local params='display notification "'${message}'" with title "'${title}'" subtitle "'${subtitle}'" sound name "Frog"'
	/usr/bin/osascript -e "$params"
}

# clear screen if run from terminal


echo "\nEnvironment Variables\n"
echo "build_jsonFile: ${build_jsonFile}"
echo "src_jsonFile: ${src_jsonFile}"
echo "src_files: ${src_files}"
echo "temp_folder: ${temp_folder}"
echo ""

echo "Create Temp Folder and Folder Structure if needed"
mkdir -p "${temp_folder}"


echo "Download resources.json if needed"

# Download if ressources file did not exist or is older than 1 day
if [[ $(find "$build_jsonFile" -mtime -1 -print) ]]; then
	echo "File $build_jsonFile exists and is max 1 day old"
else
	echo "$build_jsonFile need to be downloaded"
  	curl 'https://dl.taz.de/appGraphQl?query=query%7Bproduct%7BresourceVersion,resourceBaseUrl,resourceZip,globalBaseUrl,appType,appName%7D%7D' -o $build_jsonFile; check
  	cp "${build_jsonFile}" "${src_jsonFile}"
fi

function extract_versions_numbers() {
	jsonVersion=$(grep -o '"resourceVersion":\d.' $build_jsonFile | grep -o '\d.')
	cssVersion=$(grep 'resourceVersion' "${src_files}/scroll.css" | awk '{print $3}')
	echo "Current Versions are: jsonVersion: ${jsonVersion}  :: cssVersion: ${cssVersion} "
}

function download_and_unpack() {
	curl https://dl.taz.de/data/tApp/taz/resources/content.zip -o "${temp_folder}/resources.zip"; check
	unzip "${temp_folder}/resources.zip" -d "${temp_folder}/unzipped"; check
	rm -rf "${src_files}"; check
	mv "${temp_folder}/unzipped" "${src_files}"; check
	extract_versions_numbers
	if [[ ! $cssVersion -eq $jsonVersion ]]; then
		echo "ERROR :: Downloaded Ressources but they but did not get expected Version"
		show_notification "Downloaded Ressources but they but did not get expected Version"
		exit 1 #Abort, show Error
	fi
}

extract_versions_numbers

if [[ ! "$cssVersion" =~ ^[0-9]+$ ]]; then
	#there is no older one, download, unpack exchange (if any)
	echo "\nno css found, download ressources"
	download_and_unpack
elif [[ ! $cssVersion -eq $jsonVersion ]]; then
	#there is no older one, download, unpack exchange (if any)
	echo "\nversions did not match download ressources"
	download_and_unpack
else 
	echo "\nAlready got latest version, do nothing"
fi

rm -rf "${temp_folder}"; check

echo "\nSuccess"
exit 0