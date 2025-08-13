#!/bin/bash

DEPLOY_DIR="$(pwd)/binds/liferay/deploy"
PROJECT_NAME="$(docker compose ls --quiet)"

LIFERAY_VERSION="$(docker compose -p "${PROJECT_NAME}" exec liferay cat .liferay-version)"
GIT_HASH="$(docker compose -p "${PROJECT_NAME}" exec liferay cat .githash)"

echo "#######################################################"
echo ""
echo "  Project Info:"
echo ""
echo "  Docker Compose project name: ${PROJECT_NAME}"
echo "  Liferay version: ${LIFERAY_VERSION}"
echo "  Git hash: ${GIT_HASH}"
echo ""
echo "#######################################################"
echo ""
echo "Copy this to the build.gradle file of the module you want to deploy to the container:"
echo ""
echo "------------------------------"
echo ""

sed \
	-e "s,{{LIFERAY_VERSION}},${LIFERAY_VERSION},g" \
	-e "s,{{DEPLOY_DIR}},${DEPLOY_DIR},g" \
	./templates/scripts/build.gradle.template;

echo ""
echo "------------------------------"
echo ""
echo "See https://liferay.atlassian.net/wiki/spaces/DET/pages/3492151315/Liferay+Environment+Composer+-+Engineering+Page#Deploying-to-the-container" for more information
echo ""
echo "#######################################################"