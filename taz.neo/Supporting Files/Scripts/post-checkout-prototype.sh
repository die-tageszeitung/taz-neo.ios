#!/bin/bash

set -e

printf '\npost-checkout hook\n\n'

checkoutType=$3

if [[ $checkoutType == 1 ]]
then
	echo 'Handle branch switch'
	./taz.neo/Supporting\ Files/Scripts/refreshEnvironment.sh -b
fi
 
