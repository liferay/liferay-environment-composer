#!/bin/bash

PORT_LOWEST="${1}"
PORT_HIGHEST="${2}"

if [[ ! "${PORT_LOWEST}" -lt "${PORT_HIGHEST}" ]]; then
	>&2 echo "Port ${PORT_LOWEST} must be lower than port ${PORT_HIGHEST}"

	exit 1
fi

for port in $(seq "${PORT_LOWEST}" "${PORT_HIGHEST}"); do
	if ! netstat -an | grep "LISTEN" | grep "[.:]${port}[^0-9]" >/dev/null ; then
		echo "${port}"
		break
	fi
done