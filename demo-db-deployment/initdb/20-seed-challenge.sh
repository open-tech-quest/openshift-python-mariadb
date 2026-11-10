# Sourced by the MariaDB entrypoint after 10-schema.sql.
# Inserts the challenge flag (from the Secret otq-mariadb) into the challenge table.
# Helper functions come from docker-entrypoint.sh.

if [ -z "${CHALLENGE_NAME:-}" ] || [ -z "${CHALLENGE_FLAG:-}" ]; then
	mysql_error "CHALLENGE_NAME and CHALLENGE_FLAG must be set to seed the challenge table"
fi

mysql_note "Seeding challenge '${CHALLENGE_NAME}'"
name="$(docker_sql_escape_string_literal "${CHALLENGE_NAME}")"
flag="$(docker_sql_escape_string_literal "${CHALLENGE_FLAG}")"

docker_process_sql --database="${MARIADB_DATABASE}" <<-EOSQL
	INSERT INTO challenge (name, flag) VALUES ('${name}', '${flag}')
	ON DUPLICATE KEY UPDATE flag = VALUES(flag);
EOSQL
