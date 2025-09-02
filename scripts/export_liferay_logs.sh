#!/bin/bash

LIFERAY_EXPORTS_DIR="./exports/liferay"

mkdir -p "${LIFERAY_EXPORTS_DIR}"

docker compose cp liferay:/opt/liferay/logs "${LIFERAY_EXPORTS_DIR}" 2> /dev/null
docker compose cp liferay:/opt/liferay/reports "${LIFERAY_EXPORTS_DIR}" 2> /dev/null
docker compose cp liferay:/opt/liferay/routes "${LIFERAY_EXPORTS_DIR}" 2> /dev/null