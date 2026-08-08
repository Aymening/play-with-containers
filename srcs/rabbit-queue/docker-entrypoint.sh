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

as_rabbitmq() {
    runuser -u rabbitmq -- "$@"
}

wait_for_broker() {
    attempts=0
    until as_rabbitmq rabbitmq-diagnostics -q ping >/dev/null 2>&1; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge 60 ]; then
            echo "RabbitMQ did not become ready during initialization" >&2
            return 1
        fi
        sleep 2
    done
}

declare_queue() {
    queue_url="http://127.0.0.1:15672/api/queues/%2F/$RABBITMQ_QUEUE"
    attempts=0
    until curl --fail --silent --show-error \
        --user "$RABBITMQ_USER:$RABBITMQ_PASSWORD" \
        --header 'content-type: application/json' \
        --request PUT \
        --data '{"durable":true,"auto_delete":false,"arguments":{}}' \
        "$queue_url" >/dev/null; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge 30 ]; then
            echo "RabbitMQ management API did not accept the queue declaration" >&2
            return 1
        fi
        sleep 2
    done
}

initialize_broker() {
    require_environment RABBITMQ_USER
    require_environment RABBITMQ_PASSWORD
    require_environment RABBITMQ_QUEUE

    case "$RABBITMQ_USER" in
        guest)
            echo "RABBITMQ_USER must not use the default guest account" >&2
            exit 1
            ;;
        *[!A-Za-z0-9._-]*|'')
            echo "RABBITMQ_USER may contain only letters, numbers, dot, underscore, and hyphen" >&2
            exit 1
            ;;
    esac

    case "$RABBITMQ_QUEUE" in
        *[!A-Za-z0-9._-]*|'')
            echo "RABBITMQ_QUEUE may contain only letters, numbers, dot, underscore, and hyphen" >&2
            exit 1
            ;;
    esac

    mkdir -p "$RABBITMQ_MNESIA_BASE"
    chown -R rabbitmq:rabbitmq /var/lib/rabbitmq

    marker=/var/lib/rabbitmq/.container-initialized
    if [ -f "$marker" ]; then
        return
    fi

    echo "Initializing RabbitMQ user and durable queue"
    as_rabbitmq rabbitmq-server -detached
    trap 'as_rabbitmq rabbitmqctl shutdown >/dev/null 2>&1 || true' EXIT INT TERM
    wait_for_broker

    if as_rabbitmq rabbitmqctl -q list_users | awk -v user="$RABBITMQ_USER" '$1 == user { found = 1 } END { exit !found }'; then
        as_rabbitmq rabbitmqctl change_password "$RABBITMQ_USER" "$RABBITMQ_PASSWORD"
    else
        as_rabbitmq rabbitmqctl add_user "$RABBITMQ_USER" "$RABBITMQ_PASSWORD"
    fi
    as_rabbitmq rabbitmqctl set_permissions -p / "$RABBITMQ_USER" '.*' '.*' '.*'
    as_rabbitmq rabbitmqctl set_user_tags "$RABBITMQ_USER" management

    declare_queue
    as_rabbitmq rabbitmqctl set_user_tags "$RABBITMQ_USER"
    if as_rabbitmq rabbitmqctl -q list_users | awk '$1 == "guest" { found = 1 } END { exit !found }'; then
        as_rabbitmq rabbitmqctl delete_user guest
    fi
    as_rabbitmq rabbitmqctl shutdown
    trap - EXIT INT TERM

    touch "$marker"
    chown rabbitmq:rabbitmq "$marker"
    echo "RabbitMQ initialization complete"
}

if [ "${1:-}" = "rabbitmq-server" ]; then
    initialize_broker
    exec runuser -u rabbitmq -- "$@"
fi

exec "$@"
