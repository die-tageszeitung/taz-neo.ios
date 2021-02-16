#!/bin/sh

COUNTER=0
while [ $COUNTER -lt ${SCRIPT_INPUT_FILE_COUNT} ]; do
  FILE_IN="SCRIPT_INPUT_FILE_$COUNTER"
  FILE_OUT="SCRIPT_OUTPUT_FILE_$COUNTER"
  #ls "${!FILE_IN}"
  if [ -f "${!FILE_IN}" ]; then
    cp "${!FILE_IN}" "${!FILE_OUT}"
    echo "copied ${!FILE_IN} to Intermediate Folder: ${!FILE_OUT}"
  else
    echo "Optional File not found at ${!FILE_IN}, and will be 'MISSING'"
  fi
  let COUNTER=COUNTER+1
done
echo "done"
