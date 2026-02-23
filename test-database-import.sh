#!/bin/bash

_clean_dumps_dir() {
	local dumpsFiles=($(ls dumps))

	if (( ${#dumpsFiles[@]} > 0 )); then
		for dumpsFile in ${dumpsFiles[@]}; do
			rm dumps/${dumpsFile}
		done
	fi
}

_stop_composer() {
	local databaseType=${1}

	./gradlew stop -Plr.docker.environment.clear.volume.data=true -Plr.docker.environment.service.enabled[liferay]=false -Plr.docker.environment.service.enabled[${databaseType}]=true &> /dev/null
}

_test_import_dump() {
	local fileType=${1}
	local databaseType=${2}

	local files=($(ls ./testDependencies/${fileType}/${databaseType}))

	local file

	 for file in ${files[@]}; do
		echo "Testing ${file}..."

		cp "testDependencies/${fileType}/${databaseType}/${file}" "dumps/${file}"

		./gradlew clean start -Plr.docker.environment.service.enabled[liferay]=false -Plr.docker.environment.service.enabled[${databaseType}]=true -Plr.docker.environment.lxc.backup.password=12345 &> /dev/null

		local status=$?

		if [[ ${status} != 0 ]]; then
			echo "[FAILED]"

			_stop_composer ${databaseType}

			_clean_dumps_dir

			continue
		fi

		local sqlQueryOutput=$(./gradlew executeSQLQuery -Plr.docker.environment.service.enabled[${databaseType}]=true -PsqlQuery="select urlTitle from JournalArticle;")

		if [[ ${sqlQueryOutput} =~ "test-web-content-title" ]]; then
			echo "[PASSED]"
		else
			echo "[FAILED]"
		fi

		_stop_composer ${databaseType}

		_clean_dumps_dir
	done
}

test_database_archive_formats() {
	_test_import_dump archives mysql
}

test_db2_dump_formats() {
	_test_import_dump archives db2
}

test_mariadb_dump() {
	_test_import_dump raw mariadb
}

test_mysql_dump() {
	_test_import_dump raw mysql
}

test_postgres_dump_formats() {
	_test_import_dump raw postgres
}

test_sqlserver_dump_formats() {
	_test_import_dump archives sqlserver
	_test_import_dump raw sqlserver
}

_clean_dumps_dir

test_database_archive_formats
test_db2_dump_formats
test_mariadb_dump
test_mysql_dump
test_postgres_dump_formats
test_sqlserver_dump_formats