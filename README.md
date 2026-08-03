# CRUD Microservices with Vagrant

This project is a three-service CRUD and asynchronous messaging system deployed
across three Ubuntu virtual machines. A Flask API Gateway is the public entry
point, a Flask Inventory API stores movies in PostgreSQL, and a Billing worker
consumes persistent RabbitMQ messages and stores orders in a separate
PostgreSQL database.

The repository provides automated Vagrant provisioning, centralized `.env`
configuration, PM2 process management, a complete Postman collection, and an
OpenAPI description of the public Gateway API.

## Architecture

```text
                                      HTTP
Client ── /api/movies* ──▶ API Gateway ──────▶ Inventory API
                           gateway-vm          inventory-vm
                           :5002               :8080
                                                  │
                                                  ▼
                                             PostgreSQL
                                             movies_db

                                      AMQP
Client ── /api/billing ──▶ API Gateway ──────▶ RabbitMQ billing_queue
                           gateway-vm          billing-vm
                                                  │
                                                  ▼
                                             Billing worker
                                             managed by PM2
                                                  │
                                                  ▼
                                             PostgreSQL
                                             orders_db
```

Movie requests are sent synchronously from the Gateway to the Inventory API.
The Gateway preserves the Inventory response body, status code, and relevant
headers. Billing requests are asynchronous: the Gateway publishes the original
JSON request body as a persistent RabbitMQ message, returns immediately, and
the Billing worker inserts the order later.

### Virtual machines and network

| Machine | Private IP | Main responsibility | Guest port | Host port |
|---|---|---|---:|---:|
| `gateway-vm` | `192.168.56.10` | API Gateway | 5002 | 5002 |
| `inventory-vm` | `192.168.56.11` | Inventory API | 8080 | 8080 |
| `billing-vm` | `192.168.56.12` | PostgreSQL | 5432 | 5433 |
| `billing-vm` | `192.168.56.12` | RabbitMQ AMQP | 5672 | 5673 |
| `billing-vm` | `192.168.56.12` | RabbitMQ management | 15672 | 15673 |

The services communicate over the private `192.168.56.0/24` network. The host
port mappings make the APIs and supporting services accessible from the host
machine during development and testing.

## Main design decisions

- Each service runs in its own VM to isolate application and infrastructure
  failures.
- Inventory and Billing own separate PostgreSQL databases.
- The Gateway uses HTTP for synchronous movie operations and RabbitMQ for
  asynchronous billing operations.
- `billing_queue` is durable and published messages use persistent delivery.
- The Billing worker uses manual acknowledgements. It acknowledges a message
  only after the database transaction succeeds.
- PM2 keeps each Python process running and restores saved processes after a VM
  restart.
- Configuration is read from the root `.env`; required values have no runtime
  credential fallbacks in the application source.
- Both trailing-slash and non-trailing-slash API paths are accepted.

## Repository structure

```text
.
├── .env
├── Vagrantfile
├── ecosystem.config.js
├── openapi.yaml
├── CRUD_Master_Py.postman_collection.json
├── scripts/
│   ├── install_gateway.sh
│   ├── install_inventory.sh
│   └── install_billing.sh
└── srcs/
    ├── api-gateway-app/
    ├── inventory-app/
    └── billing-app/
```

## Prerequisites

Install the following tools on the host:

- VirtualBox or another Vagrant-compatible provider
- Vagrant
- Postman
- At least 4 GB of available memory
- Host ports `5002`, `8080`, `5433`, `5673`, and `15673` available

Verify the command-line tools:

```bash
vagrant --version
VBoxManage --version
```

Run all commands in this guide from the repository root unless stated
otherwise.

## Environment configuration

The root `.env` is the central configuration file. It must exist before the VMs
are provisioned.

| Variable | Purpose |
|---|---|
| `GATEWAY_IP` | Gateway private IP |
| `INVENTORY_IP` | Inventory private IP |
| `BILLING_IP` | Billing private IP |
| `GATEWAY_PORT` | Public Gateway HTTP port |
| `INVENTORY_PORT` | Inventory HTTP port |
| `INVENTORY_SERVICE_URL` | Inventory base URL used by the Gateway |
| `INVENTORY_DB_USER` | Inventory PostgreSQL role |
| `INVENTORY_DB_PASSWORD` | Inventory PostgreSQL password |
| `INVENTORY_DB_HOST` | Inventory PostgreSQL host |
| `INVENTORY_DB_PORT` | Inventory PostgreSQL guest port |
| `INVENTORY_DB_NAME` | Inventory database name (`movies_db`) |
| `BILLING_DB_USER` | Billing PostgreSQL role |
| `BILLING_DB_PASS` | Billing PostgreSQL password |
| `BILLING_DB_NAME` | Billing database name (`orders_db`) |
| `BILLING_DB_HOST` | Billing PostgreSQL host |
| `BILLING_DB_PORT` | Billing PostgreSQL guest port |
| `RABBITMQ_HOST` | RabbitMQ host |
| `RABBITMQ_PORT` | RabbitMQ AMQP guest port |
| `RABBITMQ_USER` | RabbitMQ application user |
| `RABBITMQ_PASS` | RabbitMQ application password |
| `RABBITMQ_QUEUE` | Queue name (`billing_queue`) |

The Vagrant shared directory mounts the repository at `/vagrant` in every VM.
Inventory and Billing provisioning source `/vagrant/.env`, and the Python
applications load the same file at runtime because their PM2 working directory
is `/vagrant`. Missing required values cause the service to fail fast with a
clear configuration error.

The included credentials are intended only for an isolated development lab.
Replace them before using the project in any shared or production environment.

## Automated provisioning

Validate the Vagrant configuration:

```bash
vagrant validate
```

Create and provision all three VMs:

```bash
vagrant up
```

Provisioning can take several minutes on the first run. The scripts perform the
following work automatically:

- `install_gateway.sh` installs Python, Node.js, PM2, and Gateway dependencies,
  creates a Python virtual environment, enables PM2 startup, and starts
  `api-gateway`.
- `install_inventory.sh` validates Inventory environment values, installs and
  configures PostgreSQL, creates the database and role, grants table and
  sequence permissions, installs application dependencies, and starts
  `inventory-app`.
- `install_billing.sh` validates Billing and RabbitMQ values, installs and
  configures PostgreSQL and RabbitMQ, creates the database and broker user,
  installs application dependencies, and starts `billing_app` under root PM2.

Provision one VM again after changing a setup script:

```bash
vagrant provision gateway-vm
vagrant provision inventory-vm
vagrant provision billing-vm
```

Check that all VMs are running:

```bash
vagrant status
```

Expected machines:

```text
gateway-vm     running
inventory-vm   running
billing-vm     running
```

## Verify processes and infrastructure

Check the managed application processes:

```bash
vagrant ssh gateway-vm -c "pm2 status"
vagrant ssh inventory-vm -c "pm2 status"
vagrant ssh billing-vm -c "sudo pm2 status"
```

Expected PM2 process names:

| VM | Process | Expected state |
|---|---|---|
| `gateway-vm` | `api-gateway` | `online` |
| `inventory-vm` | `inventory-app` | `online` |
| `billing-vm` | `billing_app` | `online` |

Billing is intentionally managed by root PM2 because the resilience audit uses
`sudo pm2 stop billing_app` and `sudo pm2 start billing_app`. Running plain
`pm2 status` on `billing-vm` checks a different PM2 account and may show an empty
list.

Check PostgreSQL and RabbitMQ:

```bash
vagrant ssh inventory-vm -c "sudo systemctl is-active postgresql"
vagrant ssh billing-vm -c \
  "sudo systemctl is-active postgresql rabbitmq-server"
```

Each command should print `active` for the requested services.

## API reference

The Gateway is available from the host at `http://localhost:5002`. The
Inventory API is also exposed directly at `http://localhost:8080` for service
testing.

### Movie endpoints

| Method | Path | Behavior | Success |
|---|---|---|---:|
| `GET` | `/api/movies` | Return all movies; accepts `?title=value` | 200 |
| `POST` | `/api/movies` | Create a movie | 201 |
| `DELETE` | `/api/movies` | Delete all movies | 200 |
| `GET` | `/api/movies/{id}` | Return one movie | 200 |
| `PUT` | `/api/movies/{id}` | Update one or both movie fields | 200 |
| `DELETE` | `/api/movies/{id}` | Delete one movie | 200 |

A missing movie returns `404`. A create request without `title` and an invalid
update payload return `400`.

Create a movie through the Gateway:

```bash
curl -i -X POST http://localhost:5002/api/movies/ \
  -H "Content-Type: application/json" \
  -d '{"title":"A new movie","description":"Very short description"}'
```

Expected status: `201 CREATED`. Save the returned `id` for the item-specific
commands.

List all movies:

```bash
curl -i http://localhost:5002/api/movies/
```

Filter by title; matching is case-insensitive and partial:

```bash
curl -i "http://localhost:5002/api/movies?title=new%20movie"
```

Retrieve and update a movie:

```bash
curl -i http://localhost:5002/api/movies/MOVIE_ID

curl -i -X PUT http://localhost:5002/api/movies/MOVIE_ID \
  -H "Content-Type: application/json" \
  -d '{"title":"Updated movie","description":"Updated description"}'
```

Delete one movie:

```bash
curl -i -X DELETE http://localhost:5002/api/movies/MOVIE_ID
```

Confirming the same ID after deletion should return `404 NOT FOUND`:

```bash
curl -i http://localhost:5002/api/movies/MOVIE_ID
```

Delete every movie:

```bash
curl -i -X DELETE http://localhost:5002/api/movies/
```

This last command is destructive and intentionally removes every row from the
Inventory database.

### Direct Inventory checks

Use port `8080` to test the Inventory service without the Gateway:

```bash
curl -i http://localhost:8080/api/movies/
curl -i "http://localhost:8080/api/movies?title=new"
```

All movie methods and paths listed above are supported directly by Inventory.
The same requests made through port `5002` should produce the same response
payload and status.

### Billing endpoint

| Method | Path | Behavior | Success |
|---|---|---|---:|
| `POST` | `/api/billing` | Publish an order to `billing_queue` | 200 |

Queue an order through the Gateway:

```bash
curl -i -X POST http://localhost:5002/api/billing/ \
  -H "Content-Type: application/json" \
  -d '{"user_id":"20","number_of_items":"99","total_amount":"250"}'
```

Expected response:

```json
{"message":"Message posted"}
```

The Gateway requires `user_id`, `number_of_items`, and `total_amount`. It
returns `400` when the request is not JSON or a required field is absent. A
successful response means RabbitMQ accepted the message; database insertion is
performed asynchronously by the Billing worker.

There is no direct Billing HTTP endpoint. Billing is tested by calling the
Gateway and then checking RabbitMQ and `orders_db`.

## PostgreSQL verification

### Inventory database

List databases and inspect the movies table:

```bash
vagrant ssh inventory-vm
sudo -i -u postgres
psql
\l
\c movies_db
TABLE movies;
\q
exit
exit
```

The expected schema is:

| Column | Type | Constraint |
|---|---|---|
| `id` | `INTEGER` | Primary key, auto-increment |
| `title` | `VARCHAR(255)` | Not null |
| `description` | `TEXT` | Nullable |

The same check can be performed without opening an interactive session:

```bash
vagrant ssh inventory-vm -c \
  "cd /tmp && sudo -u postgres psql -d movies_db -c 'TABLE movies;'"
```

### Billing database

List databases and inspect the orders table:

```bash
vagrant ssh billing-vm
sudo -i -u postgres
psql
\l
\c orders_db
TABLE orders;
\q
exit
exit
```

The expected schema is:

| Column | Type | Constraint |
|---|---|---|
| `id` | `INTEGER` | Primary key, auto-increment |
| `user_id` | `VARCHAR(50)` | Not null |
| `number_of_items` | `INTEGER` | Not null |
| `total_amount` | `NUMERIC(10,2)` | Not null |

Query recent orders directly:

```bash
vagrant ssh billing-vm -c \
  "cd /tmp && sudo -u postgres psql -d orders_db -c \
  'SELECT id, user_id, number_of_items, total_amount FROM orders ORDER BY id DESC LIMIT 10;'"
```

## RabbitMQ and asynchronous resilience test

First confirm that the queue exists, is durable, and has an active consumer:

```bash
vagrant ssh billing-vm -c \
  "sudo rabbitmqctl list_queues name durable messages_ready messages_unacknowledged consumers"
```

With the worker running, the expected steady state is:

```text
billing_queue  true  0  0  1
```

Perform the complete outage and recovery test as follows.

1. Stop the Billing worker and confirm its state:

```bash
vagrant ssh billing-vm -c "sudo pm2 stop billing_app && sudo pm2 list"
```

The `billing_app` status must be `stopped`.

2. Send an order while the worker is stopped:

```bash
curl -i -X POST http://localhost:5002/api/billing/ \
  -H "Content-Type: application/json" \
  -d '{"user_id":"22","number_of_items":"10","total_amount":"50"}'
```

The Gateway must still return `200 OK` because RabbitMQ remains available.

3. Confirm that the message is waiting in RabbitMQ:

```bash
vagrant ssh billing-vm -c \
  "sudo rabbitmqctl list_queues name durable messages_ready messages_unacknowledged consumers"
```

`messages_ready` should be at least `1`, while `consumers` should be `0`.

4. Confirm that the stopped worker has not written the order:

```bash
vagrant ssh billing-vm -c \
  "cd /tmp && sudo -u postgres psql -d orders_db -c \
  \"SELECT * FROM orders WHERE user_id = '22';\""
```

The query should return no new user `22` row.

5. Restart the worker:

```bash
vagrant ssh billing-vm -c "sudo pm2 start billing_app && sudo pm2 list"
```

6. Query PostgreSQL again:

```bash
vagrant ssh billing-vm -c \
  "cd /tmp && sudo -u postgres psql -d orders_db -c \
  \"SELECT * FROM orders WHERE user_id = '22' ORDER BY id DESC;\""
```

The order should now be present.

7. Confirm that the queue returned to its steady state:

```bash
vagrant ssh billing-vm -c \
  "sudo rabbitmqctl list_queues name durable messages_ready messages_unacknowledged consumers"
```

The expected values are `messages_ready = 0`, `messages_unacknowledged = 0`,
and `consumers = 1`. This demonstrates that the message survived the worker
outage and was acknowledged after successful processing.

## Postman testing

Import the complete collection from the repository root:

```text
CRUD_Master_Py.postman_collection.json
```

In Postman:

1. Select **Import**.
2. Select **Files** and choose the root collection JSON.
3. Select **No environment**. The collection already defines:
   - `inventoryUrl = http://localhost:8080`
   - `gatewayUrl = http://localhost:5002`
4. Run the entire collection in order with the Collection Runner.

The complete collection contains:

- 10 direct Inventory requests covering POST, GET, title filtering, GET by ID,
  PUT, DELETE by ID, expected 404 behavior, and DELETE all.
- 11 Gateway requests covering the same movie behavior through the HTTP proxy
  plus `POST /api/billing/` through RabbitMQ.
- 21 request tests and 42 assertions in total.

The two folders are named **Inventory API** and **API Gateway**. Billing appears
as the final request in the Gateway folder because Billing has no public HTTP
service of its own.

Important expected behavior:

- The create requests return `201`.
- The negative GET after DELETE returns `404`; this is an expected passing test.
- Billing returns `200`.
- The collection tests DELETE all and therefore leaves the movies table empty.

Run the same collection from the terminal with Newman if Node.js is available
on the host:

```bash
npx --yes newman run CRUD_Master_Py.postman_collection.json --bail
```

The expected summary is 21 executed requests, 42 assertions, and 0 failures.

## OpenAPI documentation

The public Gateway contract is defined in:

```text
openapi.yaml
```

It documents all public movie operations, title filtering, the asynchronous
billing endpoint, request schemas, response schemas, and error responses. It
includes both host-forwarded and private-network Gateway server URLs.

## Logs and service operations

Inspect recent application logs:

```bash
vagrant ssh gateway-vm -c "pm2 logs api-gateway --lines 50 --nostream"
vagrant ssh inventory-vm -c "pm2 logs inventory-app --lines 50 --nostream"
vagrant ssh billing-vm -c \
  "sudo pm2 logs billing_app --lines 50 --nostream"
```

Restart an application after a code or configuration change:

```bash
vagrant ssh gateway-vm -c "pm2 restart api-gateway"
vagrant ssh inventory-vm -c "pm2 restart inventory-app"
vagrant ssh billing-vm -c "sudo pm2 restart billing_app"
```

Stop or start all VMs:

```bash
vagrant halt
vagrant up
```

## Troubleshooting

### Gateway returns `503 Inventory service unavailable`

The Gateway is running but cannot reach Inventory. Check the Inventory process
and its direct endpoint:

```bash
vagrant ssh inventory-vm -c "pm2 status"
vagrant ssh inventory-vm -c \
  "pm2 logs inventory-app --lines 50 --nostream"
curl -i http://localhost:8080/api/movies
```

Also confirm that `INVENTORY_SERVICE_URL` in `.env` points to
`http://192.168.56.11:8080`.

### Host request is refused or reset

Confirm the VM and PM2 process are running:

```bash
vagrant status
vagrant ssh gateway-vm -c "pm2 status"
vagrant ssh inventory-vm -c "pm2 status"
```

If configuration or provisioning changed, provision the affected VM and
restart its process.

### Billing PM2 list appears empty

Use `sudo pm2 status` on `billing-vm`. The Billing worker belongs to root PM2;
plain `pm2 status` reads the `vagrant` user's separate PM2 process list.

### Billing messages remain ready

A backlog is expected while `billing_app` is stopped. Start it and inspect the
worker logs:

```bash
vagrant ssh billing-vm -c "sudo pm2 start billing_app"
vagrant ssh billing-vm -c \
  "sudo pm2 logs billing_app --lines 50 --nostream"
```

### Postman import fails

Import the root JSON as a **file**, not as pasted text or an API specification.
If the desktop application still rejects it, restart or update Postman and
import the file again. The collection format is Postman Collection v2.1.

## Final verification checklist

- `vagrant validate` succeeds.
- All three machines report `running` in `vagrant status`.
- `api-gateway`, `inventory-app`, and `billing_app` are online.
- PostgreSQL and RabbitMQ report `active` where required.
- `movies_db.movies` and `orders_db.orders` have the documented schemas.
- Gateway movie responses match Inventory status codes and JSON payloads.
- Title filtering returns only matching movies.
- The Postman collection completes with no failed assertions.
- Billing returns `200` while the worker is stopped.
- RabbitMQ retains the pending billing message during the outage.
- Restarting the worker stores the order and clears the queue.
- The OpenAPI file matches the implemented public Gateway routes.
