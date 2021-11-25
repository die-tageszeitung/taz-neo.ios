#!/bin/bash
if [[ $checkoutType == 1 ]]
then
	echo 'Handle branch switch'
	./taz.neo/Supporting\ Files/Scripts/refreshEnvironment.sh -b
fi