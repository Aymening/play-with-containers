#!/bin/sh
set -e

# Check the settings we need.
if [ -z "${RABBITMQ_USER:-}" ]; then
    echo "RABBITMQ_USER is required" >&2
    exit 1
fi

if [ -z "${RABBITMQ_PASSWORD:-}" ]; then
    echo "RABBITMQ_PASSWORD is required" >&2
    exit 1
fi

if [ -z "${RABBITMQ_QUEUE:-}" ]; then
    echo "RABBITMQ_QUEUE is required" >&2
    exit 1
fi

if [ "$RABBITMQ_USER" = "guest" ]; then
    echo "Do not use guest as RABBITMQ_USER" >&2
    exit 1
fi

# Simple names make the queue URL safe.
case "$RABBITMQ_USER$RABBITMQ_QUEUE" in
    *[!A-Za-z0-9._-]*)
        echo "RabbitMQ user and queue names contain invalid characters" >&2
        exit 1
        ;;
esac

mkdir -p "$RABBITMQ_MNESIA_BASE"
chown -R rabbitmq:rabbitmq /var/lib/rabbitmq

MARKER_FILE=/var/lib/rabbitmq/.initialized

# Run this setup only for a new RabbitMQ volume.
if [ ! -f "$MARKER_FILE" ]; then
    echo "Starting RabbitMQ for first-time setup"
    runuser -u rabbitmq -- rabbitmq-server -detached

    # Wait until RabbitMQ is ready.
    READY=false
    for attempt in $(seq 1 60); do
        if runuser -u rabbitmq -- rabbitmq-diagnostics -q check_running >/dev/null 2>&1; then
            READY=true
            break
        fi
        sleep 2
    done

    if [ "$READY" != "true" ]; then
        echo "RabbitMQ did not start" >&2
        exit 1
    fi

    # Create or update the application user.
    if runuser -u rabbitmq -- rabbitmqctl -q list_users | awk -v user="$RABBITMQ_USER" '$1 == user { found = 1 } END { exit !found }'; then
        runuser -u rabbitmq -- rabbitmqctl change_password "$RABBITMQ_USER" "$RABBITMQ_PASSWORD"
    else
        runuser -u rabbitmq -- rabbitmqctl add_user "$RABBITMQ_USER" "$RABBITMQ_PASSWORD"
    fi

    runuser -u rabbitmq -- rabbitmqctl set_permissions -p / "$RABBITMQ_USER" '.*' '.*' '.*'
    runuser -u rabbitmq -- rabbitmqctl set_user_tags "$RABBITMQ_USER" management

    # Create the durable billing queue through the local management API.
    QUEUE_URL="http://127.0.0.1:15672/api/queues/%2F/$RABBITMQ_QUEUE"
    curl --fail --retry 20 --retry-delay 2 \
        --silent --show-error \
        --user "$RABBITMQ_USER:$RABBITMQ_PASSWORD" \
        --header 'content-type: application/json' \
        --request PUT \
        --data '{"durable":true,"auto_delete":false,"arguments":{}}' \
        "$QUEUE_URL"

    # The application user does not need access to the management page.
    runuser -u rabbitmq -- rabbitmqctl set_user_tags "$RABBITMQ_USER"
    runuser -u rabbitmq -- rabbitmqctl delete_user guest || true

    runuser -u rabbitmq -- rabbitmqctl shutdown
    touch "$MARKER_FILE"
    chown rabbitmq:rabbitmq "$MARKER_FILE"
    echo "RabbitMQ setup finished"
fi

# Start RabbitMQ as a non-root user.
exec runuser -u rabbitmq -- "$@"
