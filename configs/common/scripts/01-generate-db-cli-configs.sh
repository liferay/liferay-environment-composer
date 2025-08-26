#!/usr/bin/env bash

# set -o errexit

# source /mnt/liferay/scripts/_common.sh

DATABASE_HOST="database--route"

  # 180       write "            - LCP_LIFERAY_UPGRADE_ENABLED=\${LCP_LIFERAY_UPGRADE_ENABLED:-}"
  # 181:      write "            - LCP_SECRET_DATABASE_HOST=database"
  # 182       write "            - LCP_SECRET_DATABASE_PASSWORD=password"
  # 183       write "            - LCP_SECRET_DATABASE_USER=root"


main() {
    DATABASE_HOST="database"
    DATABASE__ROUTE_SERVICE_PORT="3306"
    LCP_SECRET_DATABASE_NAME="lportal"
    LCP_SECRET_DATABASE_USER="root"

    generate_config_mysql_client
    # generate_config_postgres_client
}

generate_config_mysql_client() {
  echo -e "\n[SaaS] Mysql Client Configuration"
  echo -e "\n[SaaS] Generating my.conf file for mysql-client"

  echo -e "\thost=${DATABASE_HOST}"
  echo -e "\tport=${DATABASE__ROUTE_SERVICE_PORT}"
  echo -e "\tdatabase=${LCP_SECRET_DATABASE_NAME}"
  echo -e "\tuser=${LCP_SECRET_DATABASE_USER}"

  CONFIG_FILE=~/.my.cnf

  echo -e "[mysql] \nhost=\"${DATABASE_HOST}\" \nport=\"${DATABASE__ROUTE_SERVICE_PORT}\" \ndatabase=\"${LCP_SECRET_DATABASE_NAME}\" \nuser=\"${LCP_SECRET_DATABASE_USER}\" \npassword=\"${LCP_SECRET_DATABASE_PASSWORD}\"" > ${CONFIG_FILE}

  chmod 600 ${CONFIG_FILE}
}

generate_config_postgres_client() {
  echo -e "\n[SaaS] PostgresSQL Client Configuration"
  echo -e "\n[SaaS] Generating .pgpass file for PostgresSQL psql client"

  export PGUSER=${LCP_SECRET_DATABASE_USER}

  CONFIG_FILE=~/.pgpass

  echo -e "${DATABASE_HOST}:${DATABASE__ROUTE_SERVICE_PORT}:${LCP_SECRET_DATABASE_NAME}:${LCP_SECRET_DATABASE_USER}:${LCP_SECRET_DATABASE_PASSWORD}" > ${CONFIG_FILE}

  chmod 600 ${CONFIG_FILE}

  add_to_bash_rc "export PGDATABASE=${LCP_SECRET_DATABASE_NAME}"
  add_to_bash_rc "export PGHOST=${DATABASE_HOST}"
  add_to_bash_rc "export PGUSER=${LCP_SECRET_DATABASE_USER}"

  source ~/.bashrc
}

add_to_bash_rc() {
    echo -e "\n${1}" >> ~/.bashrc
}

main "$@"