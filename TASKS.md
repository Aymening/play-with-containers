# Play with Containers — Tasks

Use this checklist to track the mandatory work for the project. Complete the CRUD application cleanup before starting the container infrastructure.

## 1. Prepare the application services

- [x] Keep the Inventory API focused on movie CRUD operations.
- [x] Keep the API Gateway responsible for public movie and billing requests.
- [x] Keep the Billing application responsible for consuming RabbitMQ messages and storing orders.
- [x] Remove unused CRUD-master code, comments, dependencies, and scripts.
- [x] Test all Inventory CRUD operations locally.
- [x] Test billing message validation and database insertion locally.
- [x] Confirm each application reads credentials and service addresses from environment variables.

## 2. Create the six required containers

Each service must have its own Dockerfile and container. The service name and built image name must match.

- [x] `inventory-db`: PostgreSQL server for the inventory database, listening internally on port `5432`.
- [x] `billing-db`: PostgreSQL server for the billing database, listening internally on port `5432`.
- [x] `inventory-app`: Inventory API connected to `inventory-db`, listening internally on port `8080`.
- [x] `billing-app`: RabbitMQ consumer connected to `billing-db`, listening internally on port `8080`.
- [x] `rabbit-queue`: RabbitMQ server containing the durable billing queue.
- [x] `api-gateway-app`: Public gateway listening on port `3000` and forwarding requests to the internal services.

## 3. Build compliant Docker images

- [x] Add the missing Dockerfile for `api-gateway-app`.
- [x] Add the missing Dockerfile for `billing-app`.
- [x] Review the existing Dockerfiles for the database, Inventory, and RabbitMQ services.
- [x] Use the penultimate stable release of Debian or Alpine as the base image.
- [x] Use explicit base-image versions; do not use `latest`.
- [x] Build every project service image locally.
- [x] Do not use prebuilt service images from Docker Hub; only Debian or Alpine base images are allowed.
- [x] Minimize image layers and remove package-manager caches.
- [x] Run application processes as non-root users where possible.
- [x] Add appropriate health checks and stop signals.

## 4. Define Docker Compose infrastructure

- [x] Create `docker-compose.yml` at the project root.
- [x] Define all six services in Compose.
- [x] Set each service's `image` name equal to its service name.
- [x] Build every image through Compose.
- [x] Configure services to restart automatically after failures.
- [x] Add dependency and health conditions where startup order matters.
- [x] Ensure the full infrastructure can be created, stopped, restarted, and deleted only with Docker Compose.

## 5. Configure networking and access

- [x] Create one Docker bridge network shared by all six services.
- [x] Use Compose service names for communication between containers.
- [x] Publish only `api-gateway-app` to the host.
- [x] Map the configured host port to gateway port `3000`.
- [x] Do not publish Inventory, Billing, PostgreSQL, or RabbitMQ ports to the host.
- [x] Confirm external clients can access the system only through the API Gateway.

## 6. Configure persistent volumes

- [x] Create an `inventory-db` volume mounted at the PostgreSQL data directory.
- [x] Create a `billing-db` volume mounted at the PostgreSQL data directory.
- [x] Create an `api-gateway-app` volume for gateway logs.
- [x] Confirm database data survives container recreation.
- [x] Confirm gateway logs survive container recreation.

## 7. Manage configuration and credentials

- [x] Keep all passwords and credentials in `.env`.
- [x] Keep `.env` ignored by Git.
- [x] Maintain `.env.example` with safe placeholder values and every required variable.
- [x] Remove unused environment variables.
- [x] Pass only the variables needed by each service through Compose.
- [x] Confirm no real credentials exist in tracked files or Git history.

## 8. Verify the complete request flow

- [x] Start the infrastructure with `docker compose up --build -d`.
- [x] Confirm all six containers are running and healthy.
- [x] Create a movie through `POST /api/movies` on port `3000`.
- [x] List movies through `GET /api/movies`.
- [x] Filter movies with `GET /api/movies?title=...`.
- [x] Retrieve one movie through `GET /api/movies/{id}`.
- [x] Update one movie through `PUT /api/movies/{id}`.
- [x] Delete one movie through `DELETE /api/movies/{id}`.
- [x] Delete all movies through `DELETE /api/movies`.
- [x] Submit an order through `POST /api/billing`.
- [x] Confirm RabbitMQ receives and acknowledges the billing message.
- [x] Confirm `billing-app` stores the order in `billing-db`.
- [x] Confirm invalid requests return suitable `400` responses.
- [x] Confirm unavailable internal services return suitable gateway errors.

## 9. Test reliability and isolation

- [x] Restart each container and confirm it recovers automatically.
- [x] Force an application failure and confirm the restart policy works.
- [x] Recreate database containers and confirm their data remains available.
- [x] Verify internal service ports cannot be reached from the host.
- [x] Inspect the network and confirm every service is attached.
- [x] Inspect the volumes and confirm all required mounts exist.
- [x] Run the Postman collection against the gateway.
- [x] Validate `openapi.yaml` against the implemented API behavior.

## 10. Finish the documentation

- [x] Update `README.md` with prerequisites.
- [x] Document `.env` configuration using non-secret examples.
- [x] Document build, start, stop, restart, log, and cleanup commands.
- [x] Document every public API endpoint with request examples.
- [x] Document the service architecture, network, and volumes.
- [x] Explain how to inspect containers, health status, logs, databases, and the RabbitMQ queue.
- [x] Add common troubleshooting steps.
- [x] Ensure all referenced architecture images exist in the repository.

## 11. Final audit

- [x] Run `docker compose config` successfully.
- [x] Build the project from a clean state.
- [x] Run the complete functional test sequence.
- [x] Check that only port `3000` is published.
- [x] Check that no container uses a forbidden prebuilt service image.
- [x] Check that every container has the correct name, image, network, volume, and restart policy.
- [x] Check the Git working tree for temporary files, caches, secrets, and unrelated artifacts.
- [x] Re-read the subject and confirm every mandatory requirement is demonstrated.

## Bonus

Start bonus work only after every mandatory item passes.

- [ ] Add automated API integration tests.
- [ ] Add structured logging and request correlation IDs.
- [ ] Add graceful RabbitMQ reconnection and retry handling.
- [ ] Add database migrations.
- [ ] Add resource limits or additional observability without changing the required architecture.
