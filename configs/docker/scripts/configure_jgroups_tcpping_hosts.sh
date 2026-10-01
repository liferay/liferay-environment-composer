#!/bin/bash

# The Liferay image sources this script before Liferay starts. JGroups TCPPING
# resolves its hosts when the channel starts and fails on any host that does
# not resolve, such as a container that is not running. So the hosts in
# JGROUPS_TCPPING_OPTIONAL_HOSTS are only added to JGROUPS_TCPPING_INITIAL_HOSTS
# if they resolve now.

function _addResolvableJGroupsHosts() {
	local host
	local hosts
	local optionalHosts

	hosts="${JGROUPS_TCPPING_INITIAL_HOSTS}"

	IFS="," read -r -a optionalHosts <<< "${JGROUPS_TCPPING_OPTIONAL_HOSTS}"

	for host in "${optionalHosts[@]}"; do
		if ! getent hosts "${host%%\[*}" > /dev/null; then
			echo "[LIFERAY] Leaving ${host} out of the JGroups TCPPING hosts because it does not resolve."

			continue
		fi

		hosts="${hosts:+${hosts},}${host}"
	done

	JGROUPS_TCPPING_INITIAL_HOSTS="${hosts}"

	export JGROUPS_TCPPING_INITIAL_HOSTS

	echo "[LIFERAY] JGroups TCPPING hosts: ${JGROUPS_TCPPING_INITIAL_HOSTS}"
}

if [ -n "${JGROUPS_TCPPING_OPTIONAL_HOSTS}" ]; then
	_addResolvableJGroupsHosts
fi

unset -f _addResolvableJGroupsHosts