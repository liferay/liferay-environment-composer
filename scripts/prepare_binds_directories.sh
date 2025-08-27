#!/bin/bash

for file in "${@}" ; do
	grep --no-filename --only-matching "./binds/[^:]*" "${file}" |
	xargs -I {} mkdir -p {}
done