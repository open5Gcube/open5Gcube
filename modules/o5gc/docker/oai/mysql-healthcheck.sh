#!/bin/bash
set -eo pipefail

if [ "$MYSQL_ROOT_PASSWORD" ] && [ -z "$MYSQL_USER" ] && [ -z "$MYSQL_PASSWORD" ]; then
	echo >&2 'Healthcheck error: cannot determine root password (and MYSQL_USER and MYSQL_PASSWORD were not set)'
	exit 1
fi

host="$(hostname --ip-address || echo '127.0.0.1')"
user="${MYSQL_USER:-root}"
export MYSQL_PWD="${MYSQL_PASSWORD:-$MYSQL_ROOT_PASSWORD}"

args=(
	# force mysql to not use the local "mysqld.sock" (test "external" connectivity)
	-h"$host"
	-u"$user"
	--silent
)

if ! mysqladmin "${args[@]}" ping > /dev/null; then
	echo "Healthcheck error: Mysql port inactive"
	exit 2
fi

[[ -z "${OAI_CN5G_TYPE}" ]] && exit 0
[[ "${OAI_CN5G_TYPE}" == "minimalist" ]] && table="users"
[[ "${OAI_CN5G_TYPE}" == "basic" ]] && table="AuthenticationSubscription"

nr_of_users=$(mysql -u$user -D oai_db --silent -e "SELECT COUNT(*) FROM $table;")
if [[ $nr_of_users -eq 0 ]]; then
	echo "Healthcheck error: oai_db not populated"
	exit 3
fi

echo "Found $nr_of_users rows in oai_db.$table"
