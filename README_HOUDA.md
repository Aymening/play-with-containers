# Inventory API, Gateway Proxy and API Documentation

This document covers the Inventory API and the Gateway HTTP integration.

## Inventory API

The Flask and SQLAlchemy application is located in `srcs/inventory-app/`. It
uses PostgreSQL database `movies_db` and runs on port `8080`.

Supported routes:

| Method | Route | Purpose |
|---|---|---|
| `GET` | `/api/movies` | List movies or filter with `?title=value` |
| `POST` | `/api/movies` | Create a movie |
| `DELETE` | `/api/movies` | Delete all movies |
| `GET` | `/api/movies/{id}` | Retrieve one movie |
| `PUT` | `/api/movies/{id}` | Update one movie |
| `DELETE` | `/api/movies/{id}` | Delete one movie |

Every route accepts an optional trailing slash.

## Inventory environment variables

Inventory provisioning and runtime configuration read these values from the
root `.env` file:

```text
INVENTORY_DB_USER
INVENTORY_DB_PASSWORD
INVENTORY_DB_HOST
INVENTORY_DB_PORT
INVENTORY_DB_NAME
INVENTORY_SERVICE_URL
```

The installation script validates the variables, creates the database role and
database when necessary, and grants the role table and sequence permissions.

## Gateway HTTP proxy

The Gateway runs on port `5002`. All `/api/movies` requests are forwarded to
the Inventory service defined by `INVENTORY_SERVICE_URL`. Query parameters,
JSON request bodies, response bodies, and HTTP status codes are preserved.

Test through the Gateway:

```bash
curl -i -X POST http://localhost:5002/api/movies/ \
  -H "Content-Type: application/json" \
  -d '{"title":"A new movie","description":"Very short description"}'

curl -i http://localhost:5002/api/movies/
curl -i "http://localhost:5002/api/movies/?title=new"
```

## API specification

The complete Gateway contract is stored in `openapi.yaml` at the repository
root. It documents the movie routes, the Billing route, request schemas,
response schemas, parameters, examples, and error status codes.

## Postman collections

The complete audit export is:

```text
CRUD_Master_Py.postman_collection.json
```

Focused collections are also available in `postman/`:

```text
CRUD_Master_Py.postman_collection_inventory.json
CRUD_Master_Py.postman_collection_gateway.json
CRUD_Master_Py.postman_collection_billing.json
```

Run the Inventory and Gateway requests in collection order. They save created
movie IDs automatically and clean up temporary movie records at the end.

## PM2 commands

```bash
vagrant ssh inventory-vm -c "pm2 status"
vagrant ssh gateway-vm -c "pm2 status"

vagrant ssh inventory-vm -c "pm2 restart inventory-app"
vagrant ssh gateway-vm -c "pm2 restart api-gateway"
```
