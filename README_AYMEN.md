

# Infrastructure & Service Testing Guide

This document contains all step-by-step verification commands to test the complete end-to-end pipeline across `billing-vm`, `gateway-vm`, and `inventory-vm`.

---

## 🛠️ Pre-Test Service Startup

Ensure all background processes are running in PM2 before executing tests.

### 1. Start Billing Worker (`billing-vm`)
```bash
vagrant ssh billing-vm
sudo pm2 start /vagrant/ecosystem.config.js --only billing_app
sudo pm2 save

```

### 2. Start Gateway Service (`gateway-vm`)

```bash
vagrant ssh gateway-vm
pm2 start /vagrant/ecosystem.config.js --only api-gateway
pm2 save

```

### 3. Start Inventory Service (`inventory-vm`)

```bash
vagrant ssh inventory-vm
pm2 start /vagrant/ecosystem.config.js --only inventory-app
pm2 save

```

---

## 🧪 Service Verification & Testing Commands

### Test 1: Order Processing (Postman / Host Request)

Send a test POST request to the API Gateway using Postman or `curl`:

* **URL:** `http://192.168.56.10:5002/api/billing` (or `http://localhost:5002/api/billing` from inside `gateway-vm`)
* **Method:** `POST`
* **Headers:** `Content-Type: application/json`
* **JSON Body:**

```json
{
  "user_id": 1,
  "number_of_items": 3,
  "total_amount": 45.50
}


```
Or Curl:

*Run this from inside gateway-vm (or from your Mac host if port 5002 is exposed):*

```
curl -i -X POST http://localhost:5002/api/billing \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "number_of_items": 3, "total_amount": 45.50}'

```
*If targeting the gateway IP from your host machine:*

```
curl -i -X POST http://192.168.56.10:5002/api/billing \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "number_of_items": 3, "total_amount": 45.50}'
```




---

### Test 2: RabbitMQ Queue Persistence and Worker Recovery

This test proves that persistent messages remain queued while the Billing worker is
stopped and are processed after it starts again.

1. Stop the Billing worker:

```bash
vagrant ssh billing-vm
sudo pm2 stop billing_app
sudo pm2 status
```

2. Confirm the queue is empty before the test:

```bash
sudo rabbitmqctl list_queues name durable messages_ready messages_unacknowledged
```

The `billing_queue` should be durable, with `0` ready and `0` unacknowledged
messages before sending the test order.

3. In another host terminal, send an order through the API Gateway:

```bash
curl -i -X POST http://192.168.56.10:5002/api/billing \
  -H "Content-Type: application/json" \
  -d '{"user_id":"resilience-test","number_of_items":2,"total_amount":19.99}'
```

The Gateway should return `200 OK` after publishing the message.

4. Back in `billing-vm`, verify that the stopped worker has left the message in
the queue:

```bash
sudo rabbitmqctl list_queues name durable messages_ready messages_unacknowledged
```

The `billing_queue` should now report at least `1` ready message and `0`
unacknowledged messages.

5. Start the Billing worker and verify that the backlog is consumed:

```bash
sudo pm2 start billing_app
sudo pm2 logs billing_app --lines 20 --nostream
sudo rabbitmqctl list_queues name durable messages_ready messages_unacknowledged
```

After processing, both queue counters should return to `0`.

6. Confirm that the queued order was inserted into PostgreSQL:

```bash
sudo -u postgres psql -d orders_db -c \
  "SELECT id, user_id, number_of_items, total_amount FROM orders WHERE user_id = 'resilience-test' ORDER BY id DESC LIMIT 1;"
```

The query should return the order with `2` items and a total amount of `19.99`.

---

### Test 3: PostgreSQL Database Record Insertion (`billing-vm`)

Verify that the order event was written into the PostgreSQL `orders_db`:

```bash
cd /tmp && sudo -u postgres psql -d orders_db -c "SELECT * FROM orders;"

```

---

### Test 4: Inventory API Endpoint (`inventory-vm`)

Verify that the movie dataset endpoint is correctly serving requests:

```bash
curl -i http://localhost:8080/api/movies

```
