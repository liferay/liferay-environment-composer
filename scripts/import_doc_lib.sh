#!/bin/bash

SOURCE_DIR=${1}
DEST_DIR=${2}

mkdir -p "${DEST_DIR}"

FILEPATHS=($(find "${SOURCE_DIR}" -type f))

for FILEPATH in ${FILEPATHS[@]}; do
	if [[ ${SOURCE_DIR} == */ ]]; then
		SOURCE_DIR="${SOURCE_DIR::-1}"
	fi

	_FILEPATH=$(dirname ${FILEPATH} | sed "s,${SOURCE_DIR},${DEST_DIR},")

	if [[ ${_FILEPATH} ]]; then
		mkdir -p "${_FILEPATH}"
	fi

	touch "${_FILEPATH}/$(basename ${FILEPATH})"
done