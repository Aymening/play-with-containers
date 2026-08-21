# Play with Containers

A six-container movie inventory and asynchronous billing system built from Debian base images and managed entirely with Docker Compose.

## Architecture

```text
Client :3000
    |
api-gateway-app
    | HTTP                         | AMQP
inventory-app :8080          rabbit-queue :5672
    | PostgreSQL                   |
inventory-db :5432           billing-app :8080
                                   |
                             billing-db :5432
```

All services share the private `play-with-containers` bridge network. Only the API Gateway publishes a host port. Inventory and billing data use separate PostgreSQL volumes, RabbitMQ has its own data volume, and gateway request logs use the `api-gateway-app` volume.

| Service | Purpose | Internal port | Host access |
|---|---|---:|---|
| `api-gateway-app` | Public API and RabbitMQ publisher | 3000 | `localhost:3000` |
| `inventory-app` | Movie CRUD API | 8080 | Private |
| `inventory-db` | Inventory PostgreSQL database | 5432 | Private |
| `billing-app` | RabbitMQ consumer and health service | 8080 | Private |
| `billing-db` | Billing PostgreSQL database | 5432 | Private |
| `rabbit-queue` | Durable billing queue | 5672 | Private |

Every image is built locally from `debian:12-slim`; no prebuilt database, queue, or application image is used.

## Prerequisites

- Docker Engine or Docker Desktop with Compose
- Git and `curl`
- At least 4 GB of available memory

```bash
docker --version
docker compose version
docker info
```

## Configuration

```bash
cp .env.example .env
```

Set strong, unique passwords in the ignored `.env` file:

```dotenv
INVENTORY_DB_USER=inventory_user
INVENTORY_DB_PASSWORD=
INVENTORY_DB_NAME=inventory
BILLING_DB_USER=billing_user
BILLING_DB_PASSWORD=
BILLING_DB_NAME=billing
RABBITMQ_USER=app_user
RABBITMQ_PASSWORD=
RABBITMQ_QUEUE=billing_queue
GATEWAY_PORT=3000
```

Do not use `guest` as `RABBITMQ_USER`; the custom RabbitMQ image rejects it. Internal addresses and ports are fixed in Compose.

## Build and operate

```bash
docker compose config --quiet
docker compose up --build -d
docker compose ps
```

```bash
docker compose logs -f
docker compose logs -f api-gateway-app
docker compose restart
docker compose stop
docker compose start
docker compose down
```

Rebuild changed images with `docker compose up --build -d`. `docker compose down` preserves data. `docker compose down --volumes` permanently deletes the databases, queue state, and gateway logs.

## Public API

The base URL is `http://localhost:3000`. Trailing slashes are accepted.

```bash
# Health
curl http://localhost:3000/health

# Create, list, filter, retrieve, and update
curl -X POST http://localhost:3000/api/movies \
  -H 'Content-Type: application/json' \
  -d '{"title":"Interstellar","description":"Science fiction"}'
curl http://localhost:3000/api/movies
curl 'http://localhost:3000/api/movies?title=inter'
curl http://localhost:3000/api/movies/1
curl -X PUT http://localhost:3000/api/movies/1 \
  -H 'Content-Type: application/json' \
  -d '{"title":"Interstellar Updated","description":"Updated description"}'

# Delete one or all movies
curl -X DELETE http://localhost:3000/api/movies/1
curl -X DELETE http://localhost:3000/api/movies

# Queue a billing order
curl -X POST http://localhost:3000/api/billing \
  -H 'Content-Type: application/json' \
  -d '{"user_id":"22","number_of_items":3,"total_amount":49.99}'
```

A successful billing response means RabbitMQ accepted the durable message. `billing-app` consumes it asynchronously and inserts it into `billing-db`. See `openapi.yaml` for schemas and error responses.

## Inspect the infrastructure

```bash
docker compose ps
docker compose port api-gateway-app 3000
docker network inspect play-with-containers
docker volume inspect inventory-db billing-db api-gateway-app rabbit-queue
```

Load `.env` with `set -a; source .env; set +a`, then inspect application data:

```bash
docker compose exec inventory-db \
  psql -U "$INVENTORY_DB_USER" -d "$INVENTORY_DB_NAME" \
  -c 'SELECT id, title, description FROM movies ORDER BY id;'

docker compose exec billing-db \
  psql -U "$BILLING_DB_USER" -d "$BILLING_DB_NAME" \
  -c 'SELECT id, user_id, number_of_items, total_amount FROM orders ORDER BY id;'

docker compose exec rabbit-queue \
  rabbitmqctl list_queues name durable messages_ready messages_unacknowledged consumers

docker compose exec api-gateway-app \
  tail -n 50 /var/log/api-gateway/access.log
```

## Troubleshooting

- Unhealthy container: run `docker compose ps` and `docker compose logs --tail=100 SERVICE_NAME`.
- First startup is slow: PostgreSQL and RabbitMQ initialize before dependent services start.
- Port 3000 is busy: set another `GATEWAY_PORT` in `.env` and recreate the gateway.
- RabbitMQ rejects credentials: use a non-guest user; credentials persist in its volume after first initialization.
- Source changes are missing: run `docker compose up --build --force-recreate -d`.
- Full reset: run `docker compose down --volumes`, only when losing all project data is acceptable.

## Security and isolation

- `.env` is ignored and excluded from image build contexts.
- Only the gateway publishes a host port.
- Application containers run as an unprivileged user.
- Database and queue entrypoints drop root privileges for their server processes.
- Credentials are injected at runtime and are not committed.
