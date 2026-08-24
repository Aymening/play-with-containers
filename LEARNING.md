# Play with Containers — Learning Checklist

Use this checklist to prepare for the project audit. Mark an item complete only when you can explain it without reading the documentation and demonstrate it with the running project.

## 1. Containers and images

- [ ] Explain the difference between a Docker image and a container.
- [ ] Explain how containers differ from virtual machines.
- [ ] Explain image layers and the Docker build cache.
- [ ] Explain the difference between `RUN`, `CMD`, and `ENTRYPOINT`.
- [ ] Explain `COPY`, `WORKDIR`, `ENV`, `EXPOSE`, `USER`, and `HEALTHCHECK`.
- [ ] Explain why all project images use `debian:12-slim`.
- [ ] Explain why explicit base-image versions are preferred over `latest`.
- [ ] Explain why package-manager caches are removed from images.
- [ ] Explain why application containers run as non-root users.

## 2. Docker Compose

- [ ] Explain the purpose of `services`, `image`, and `build`.
- [ ] Explain `environment`, `depends_on`, and `condition: service_healthy`.
- [ ] Explain `ports`, `volumes`, `networks`, and `restart`.
- [ ] Explain the YAML anchor `&service-defaults` and merge key `<<:`.
- [ ] Explain how Compose builds all six local images.
- [ ] Explain the difference between `docker compose stop` and `down`.
- [ ] Explain what `docker compose down --volumes` permanently removes.
- [ ] Run and understand each command:

  - [ ] `docker compose config`
  - [ ] `docker compose build`
  - [ ] `docker compose up -d`
  - [ ] `docker compose ps`
  - [ ] `docker compose logs`
  - [ ] `docker compose restart`
  - [ ] `docker compose stop`
  - [ ] `docker compose start`
  - [ ] `docker compose down`

## 3. Project architecture

- [ ] Draw the complete architecture without looking at the README.
- [ ] Explain the responsibility of `api-gateway-app`.
- [ ] Explain the responsibility of `inventory-app`.
- [ ] Explain the responsibility of `inventory-db`.
- [ ] Explain the responsibility of `rabbit-queue`.
- [ ] Explain the responsibility of `billing-app`.
- [ ] Explain the responsibility of `billing-db`.
- [ ] Explain why Inventory and Billing use separate databases.
- [ ] Trace a movie request from the client to PostgreSQL and back.
- [ ] Trace a billing request from the client through RabbitMQ to PostgreSQL.

## 4. Docker networking

- [ ] Explain what a Docker bridge network is.
- [ ] Explain how Compose provides DNS using service names.
- [ ] Explain why containers use `inventory-db` instead of `localhost`.
- [ ] Explain the difference between an internal port and a published port.
- [ ] Explain why `EXPOSE 8080` does not publish port `8080`.
- [ ] Explain the mapping `3000:3000`.
- [ ] Explain why only `api-gateway-app` publishes a host port.
- [ ] Demonstrate that all six containers use `play-with-containers`.
- [ ] Demonstrate that only gateway port `3000` is published.

Useful commands:

```bash
docker compose ps
docker network inspect play-with-containers
docker compose port api-gateway-app 3000
```

## 5. Volumes and persistence

- [ ] Explain what a named Docker volume is.
- [ ] Explain the difference between a named volume and a bind mount.
- [ ] Explain the difference between a volume and a container writable layer.
- [ ] Explain why database data disappears without a volume.
- [ ] Explain the purpose of the `inventory-db` volume.
- [ ] Explain the purpose of the `billing-db` volume.
- [ ] Explain the purpose of the `api-gateway-app` volume.
- [ ] Explain the purpose of the extra `rabbit-queue` volume.
- [ ] Demonstrate that database data survives container recreation.
- [ ] Demonstrate that gateway logs survive container recreation.

Useful commands:

```bash
docker volume ls
docker volume inspect inventory-db
docker inspect CONTAINER_NAME
```

## 6. PostgreSQL

- [ ] Explain the difference between a database, role, table, and sequence.
- [ ] Explain the PostgreSQL data directory.
- [ ] Explain how the custom database entrypoint initializes PostgreSQL.
- [ ] Explain how database roles and passwords are created.
- [ ] Explain table ownership and database permissions.
- [ ] Explain why Inventory and Billing use different credentials.
- [ ] Explain why PostgreSQL listens on the private Docker network.
- [ ] Explain how each application constructs its database URL.
- [ ] Connect to both databases with `psql`.
- [ ] List and query the `movies` and `orders` tables.

Useful commands:

```bash
set -a; source .env; set +a

docker compose exec inventory-db \
  psql -U "$INVENTORY_DB_USER" -d "$INVENTORY_DB_NAME"

docker compose exec billing-db \
  psql -U "$BILLING_DB_USER" -d "$BILLING_DB_NAME"
```

Useful SQL:

```sql
\dt
SELECT * FROM movies;
SELECT * FROM orders;
```

## 7. RabbitMQ and billing

- [ ] Explain producers, consumers, exchanges, routing keys, and queues.
- [ ] Explain why Billing uses asynchronous messaging.
- [ ] Explain what a durable queue is.
- [ ] Explain what makes a message persistent.
- [ ] Explain manual acknowledgement and negative acknowledgement.
- [ ] Explain why malformed messages are rejected without requeueing.
- [ ] Explain `prefetch_count=1`.
- [ ] Explain `messages_ready` and `messages_unacknowledged`.
- [ ] Explain what happens when RabbitMQ is unavailable.
- [ ] Demonstrate that a billing message reaches the `orders` table.
- [ ] Demonstrate that the queue is empty after acknowledgement.

Useful command:

```bash
docker compose exec rabbit-queue \
  rabbitmqctl list_queues \
  name durable messages_ready messages_unacknowledged consumers
```

## 8. API Gateway

- [ ] Explain why every external request goes through port `3000`.
- [ ] Explain how movie requests are forwarded to Inventory.
- [ ] Explain how HTTP methods and request bodies are preserved.
- [ ] Explain how query parameters and response status codes are preserved.
- [ ] Explain why billing requests are published instead of forwarded over HTTP.
- [ ] Explain why unavailable internal services return `503`.
- [ ] Explain the difference between `400`, `404`, `500`, and `503`.
- [ ] Locate the gateway proxy and publisher code.

## 9. HTTP and CRUD

- [ ] Explain `GET`, `POST`, `PUT`, and `DELETE`.
- [ ] Explain `Content-Type: application/json`.
- [ ] Explain path parameters and query parameters.
- [ ] Explain case-insensitive title filtering.
- [ ] Explain trailing-slash handling.
- [ ] Explain request-body validation.
- [ ] Test `GET /health`.
- [ ] Test `POST /api/movies`.
- [ ] Test `GET /api/movies`.
- [ ] Test `GET /api/movies?title=...`.
- [ ] Test `GET /api/movies/{id}`.
- [ ] Test `PUT /api/movies/{id}`.
- [ ] Test `DELETE /api/movies/{id}`.
- [ ] Test `DELETE /api/movies`.
- [ ] Test `POST /api/billing`.

## 10. Health checks and startup order

- [ ] Explain the difference between running, healthy, unhealthy, and restarting.
- [ ] Explain what each project health check tests.
- [ ] Explain why databases start before applications.
- [ ] Explain why RabbitMQ starts before Billing and Gateway.
- [ ] Explain why Gateway waits for Inventory.
- [ ] Explain why `depends_on` alone does not guarantee readiness.
- [ ] Explain that health checks report health but do not restart containers.
- [ ] Inspect a container's health history.

```bash
docker compose ps
docker inspect --format '{{json .State.Health}}' CONTAINER_NAME
```

## 11. Restart policies

- [ ] Explain `restart: unless-stopped`.
- [ ] Compare `no`, `always`, `on-failure`, and `unless-stopped`.
- [ ] Explain what happens when an application process crashes.
- [ ] Explain what happens after Docker restarts.
- [ ] Explain how a manual stop affects restart behavior.
- [ ] Demonstrate that the project services recover after a restart.

## 12. Environment variables and secrets

- [ ] Explain the difference between `.env` and `.env.example`.
- [ ] Explain why `.env` must not be committed.
- [ ] Explain why `.env` is excluded by `.dockerignore`.
- [ ] Explain Compose variable interpolation.
- [ ] Explain runtime environment injection.
- [ ] Explain why secrets must not be stored in Dockerfiles.
- [ ] Explain why the RabbitMQ `guest` user is rejected.
- [ ] Explain the difference between configuration and a secret.
- [ ] Demonstrate that `.env` is ignored and untracked.

```bash
git check-ignore .env
git ls-files .env
```

## 13. Logging

- [ ] Explain stdout/stderr container logs.
- [ ] Explain persistent application file logs.
- [ ] Explain why gateway logs use a volume.
- [ ] Explain why secrets must never be logged.
- [ ] Inspect gateway container output.
- [ ] Inspect the persisted gateway access log.

```bash
docker compose logs api-gateway-app
docker compose exec api-gateway-app \
  tail /var/log/api-gateway/access.log
```

## 14. Security and isolation

- [ ] Explain the benefit of non-root containers.
- [ ] Explain the benefit of a private service network.
- [ ] Explain the benefit of minimal base images and packages.
- [ ] Explain why database ports are not published.
- [ ] Explain why the RabbitMQ management interface is not public.
- [ ] Explain the purpose of `.dockerignore`.
- [ ] Explain what to do if a real credential is committed.

## 15. Troubleshooting

- [ ] Diagnose an unavailable Docker daemon.
- [ ] Diagnose port `3000` already being used.
- [ ] Diagnose database authentication and permission failures.
- [ ] Diagnose RabbitMQ authentication failures.
- [ ] Diagnose an unhealthy container.
- [ ] Diagnose service-name resolution failures.
- [ ] Diagnose missing data after volume deletion.
- [ ] Diagnose source changes missing from an old image.
- [ ] Practice this inspection workflow:

```bash
docker compose ps
docker compose logs --tail=100 SERVICE_NAME
docker compose config
docker inspect CONTAINER_NAME
docker network inspect play-with-containers
docker volume inspect VOLUME_NAME
```

## 16. Likely audit questions

- [ ] Why use containers instead of installing everything on one machine?
- [ ] Why does each service have its own container?
- [ ] Why are there two PostgreSQL containers?
- [ ] Why use RabbitMQ for billing?
- [ ] Why is only port `3000` published?
- [ ] What is the difference between an image and a container?
- [ ] What is the difference between `EXPOSE` and Compose `ports`?
- [ ] What happens when a database container is recreated?
- [ ] What does `restart: unless-stopped` do?
- [ ] What does a health check do?
- [ ] Why does Compose use service names as hostnames?
- [ ] Why must `.env` not be committed?
- [ ] What is a durable RabbitMQ queue?
- [ ] What is message acknowledgement?
- [ ] What does `docker compose down --volumes` remove?
- [ ] Why use a non-root application user?
- [ ] Why use `debian:12-slim`?
- [ ] How do you prove only Gateway is externally accessible?
- [ ] How do you prove billing messages reach PostgreSQL?
- [ ] How would you investigate an unhealthy service?
