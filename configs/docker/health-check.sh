#!/bin/bash

function _log() {
	echo "[$(date "+%Y.%m.%d %H:%M:%S")] $1" >> health-check.log
}

if ! grep -i -E "ga" .liferay-version
then
	_log "Checking for license registration..."
	if ! grep -i -E "license validation passed" logs/liferay.*.log
	then
		_log "License not registered"
		exit 1
	fi
fi

_log "Waiting for the server to be reachable..."
if ! curl localhost:8080
then
	_log "Server not reachable"
	exit 1
fi

_log "Ready!"
exit 0