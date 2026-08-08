#!/bin/sh
set -eu

require_environment() {
    variable_name="$1"
    variable_value="$(printenv "$variable_name" || true)"
    if [ -z "$variable_value" ]; then
        echo "Missing required environment variable: $variable_name" >&2
        exit 1
    fi
}

initialize_database() {
    require_environment POSTGRES_USER
    require_environment POSTGRES_PASSWORD
    require_environment POSTGRES_DB

    mkdir -p "$PGDATA" /run/postgresql
    chown -R postgres:postgres "$PGDATA" /run/postgresql
    chmod 0700 "$PGDATA"

    if [ -s "$PGDATA/PG_VERSION" ]; then
        return
    fi

    echo "Initializing PostgreSQL data directory"
    runuser -u postgres -- initdb \
        --pgdata="$PGDATA" \
        --username=postgres \
        --auth-local=trust \
        --auth-host=scram-sha-256

    printf "\nlisten_addresses = '*'\nport = 5432\npassword_encryption = 'scram-sha-256'\n" \
        >> "$PGDATA/postgresql.conf"
    printf "\nhost all all 0.0.0.0/0 scram-sha-256\nhost all all ::/0 scram-sha-256\n" \
        >> "$PGDATA/pg_hba.conf"

    runuser -u postgres -- pg_ctl \
        --pgdata="$PGDATA" \
        --options="-c listen_addresses=''" \
        --wait start

    trap 'runuser -u postgres -- pg_ctl --pgdata="$PGDATA" --mode=fast --wait stop' EXIT INT TERM

    runuser -u postgres -- psql \
        --username=postgres \
        --dbname=postgres \
        --set=db_user="$POSTGRES_USER" \
        --set=db_password="$POSTGRES_PASSWORD" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN', :'db_user')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'db_user') \gexec
SELECT format('ALTER ROLE %I WITH PASSWORD %L', :'db_user', :'db_password') \gexec
SQL

    runuser -u postgres -- psql \
        --username=postgres \
        --dbname=postgres \
        --set=db_name="$POSTGRES_DB" \
        --set=db_user="$POSTGRES_USER" <<'SQL'
SELECT format('CREATE DATABASE %I OWNER %I', :'db_name', :'db_user')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db_name') \gexec
SQL

    runuser -u postgres -- pg_ctl \
        --pgdata="$PGDATA" \
        --mode=fast \
        --wait stop
    trap - EXIT INT TERM

    echo "PostgreSQL initialization complete"
}

if [ "${1:-}" = "postgres" ]; then
    initialize_database
    exec runuser -u postgres -- "$@" -D "$PGDATA"
fi

exec "$@"
