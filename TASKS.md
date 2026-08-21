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

- [ ] `inventory-db`: PostgreSQL server for the inventory database, listening internally on port `5432`.
- [ ] `billing-db`: PostgreSQL server for the billing database, listening internally on port `5432`.
- [ ] `inventory-app`: Inventory API connected to `inventory-db`, listening internally on port `8080`.
- [ ] `billing-app`: RabbitMQ consumer connected to `billing-db`, listening internally on port `8080`.
- [ ] `rabbit-queue`: RabbitMQ server containing the durable billing queue.
- [ ] `api-gateway-app`: Public gateway listening on port `3000` and forwarding requests to the internal services.

## 3. Build compliant Docker images

- [ ] Add the missing Dockerfile for `api-gateway-app`.
- [ ] Add the missing Dockerfile for `billing-app`.
- [ ] Review the existing Dockerfiles for the database, Inventory, and RabbitMQ services.
- [ ] Use the penultimate stable release of Debian or Alpine as the base image.
- [ ] Use explicit base-image versions; do not use `latest`.
- [ ] Build every project service image locally.
- [ ] Do not use prebuilt service images from Docker Hub; only Debian or Alpine base images are allowed.
- [ ] Minimize image layers and remove package-manager caches.
- [ ] Run application processes as non-root users where possible.
- [ ] Add appropriate health checks and stop signals.

## 4. Define Docker Compose infrastructure

- [ ] Create `docker-compose.yml` at the project root.
- [ ] Define all six services in Compose.
- [ ] Set each service's `image` name equal to its service name.
- [ ] Build every image through Compose.
- [ ] Configure services to restart automatically after failures.
- [ ] Add dependency and health conditions where startup order matters.
- [ ] Ensure the full infrastructure can be created, stopped, restarted, and deleted only with Docker Compose.

## 5. Configure networking and access

- [ ] Create one Docker bridge network shared by all six services.
- [ ] Use Compose service names for communication between containers.
- [ ] Publish only `api-gateway-app` to the host.
- [ ] Map the configured host port to gateway port `3000`.
- [ ] Do not publish Inventory, Billing, PostgreSQL, or RabbitMQ ports to the host.
- [ ] Confirm external clients can access the system only through the API Gateway.

## 6. Configure persistent volumes

- [ ] Create an `inventory-db` volume mounted at the PostgreSQL data directory.
- [ ] Create a `billing-db` volume mounted at the PostgreSQL data directory.
- [ ] Create an `api-gateway-app` volume for gateway logs.
- [ ] Confirm database data survives container recreation.
- [ ] Confirm gateway logs survive container recreation.

## 7. Manage configuration and credentials

- [ ] Keep all passwords and credentials in `.env`.
- [ ] Keep `.env` ignored by Git.
- [ ] Maintain `.env.example` with safe placeholder values and every required variable.
- [ ] Remove unused environment variables.
- [ ] Pass only the variables needed by each service through Compose.
- [ ] Confirm no real credentials exist in tracked files or Git history.

## 8. Verify the complete request flow

- [ ] Start the infrastructure with `docker compose up --build -d`.
- [ ] Confirm all six containers are running and healthy.
- [ ] Create a movie through `POST /api/movies` on port `3000`.
- [ ] List movies through `GET /api/movies`.
- [ ] Filter movies with `GET /api/movies?title=...`.
- [ ] Retrieve one movie through `GET /api/movies/{id}`.
- [ ] Update one movie through `PUT /api/movies/{id}`.
- [ ] Delete one movie through `DELETE /api/movies/{id}`.
- [ ] Delete all movies through `DELETE /api/movies`.
- [ ] Submit an order through `POST /api/billing`.
- [ ] Confirm RabbitMQ receives and acknowledges the billing message.
- [ ] Confirm `billing-app` stores the order in `billing-db`.
- [ ] Confirm invalid requests return suitable `400` responses.
- [ ] Confirm unavailable internal services return suitable gateway errors.

## 9. Test reliability and isolation

- [ ] Restart each container and confirm it recovers automatically.
- [ ] Force an application failure and confirm the restart policy works.
- [ ] Recreate database containers and confirm their data remains available.
- [ ] Verify internal service ports cannot be reached from the host.
- [ ] Inspect the network and confirm every service is attached.
- [ ] Inspect the volumes and confirm all required mounts exist.
- [ ] Run the Postman collection against the gateway.
- [ ] Validate `openapi.yaml` against the implemented API behavior.

## 10. Finish the documentation

- [ ] Update `README.md` with prerequisites.
- [ ] Document `.env` configuration using non-secret examples.
- [ ] Document build, start, stop, restart, log, and cleanup commands.
- [ ] Document every public API endpoint with request examples.
- [ ] Document the service architecture, network, and volumes.
- [ ] Explain how to inspect containers, health status, logs, databases, and the RabbitMQ queue.
- [ ] Add common troubleshooting steps.
- [ ] Ensure all referenced architecture images exist in the repository.

## 11. Final audit

- [ ] Run `docker compose config` successfully.
- [ ] Build the project from a clean state.
- [ ] Run the complete functional test sequence.
- [ ] Check that only port `3000` is published.
- [ ] Check that no container uses a forbidden prebuilt service image.
- [ ] Check that every container has the correct name, image, network, volume, and restart policy.
- [ ] Check the Git working tree for temporary files, caches, secrets, and unrelated artifacts.
- [ ] Re-read the subject and confirm every mandatory requirement is demonstrated.

## Bonus

Start bonus work only after every mandatory item passes.

- [ ] Add automated API integration tests.
- [ ] Add structured logging and request correlation IDs.
- [ ] Add graceful RabbitMQ reconnection and retry handling.
- [ ] Add database migrations.
- [ ] Add resource limits or additional observability without changing the required architecture.
