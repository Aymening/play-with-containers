import os
import requests
import pika
from flask import Blueprint, request, Response, jsonify

gateway_bp = Blueprint('gateway', __name__)

def required_environment(name):
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required Gateway configuration: {name}")
    return value


INVENTORY_SERVICE_URL = required_environment("INVENTORY_SERVICE_URL")
RABBITMQ_HOST = required_environment("RABBITMQ_HOST")
RABBITMQ_PORT = int(required_environment("RABBITMQ_PORT"))
RABBITMQ_USER = required_environment("RABBITMQ_USER")
RABBITMQ_PASS = required_environment("RABBITMQ_PASS")
RABBITMQ_QUEUE = required_environment("RABBITMQ_QUEUE")


def publish_to_rabbitmq(message_body):
    credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASS)
    parameters = pika.ConnectionParameters(
        host=RABBITMQ_HOST,
        port=RABBITMQ_PORT,
        credentials=credentials
    )
    connection = pika.BlockingConnection(parameters)
    channel = connection.channel()
    channel.queue_declare(queue=RABBITMQ_QUEUE, durable=True)
    
    channel.basic_publish(
        exchange='',
        routing_key=RABBITMQ_QUEUE,
        body=message_body,
        properties=pika.BasicProperties(delivery_mode=2)
    )
    connection.close()


# Inventory HTTP Proxy - Supporting all methods and path formats:
# /api/movies, /api/movies/, /api/movies/<id>, /api/movies/<id>/
@gateway_bp.route(
    '/api/movies',
    defaults={'path': ''},
    methods=['GET', 'POST', 'DELETE'],
    strict_slashes=False
)
@gateway_bp.route(
    '/api/movies/<path:path>',
    methods=['GET', 'PUT', 'DELETE'],
    strict_slashes=False
)
def proxy_to_inventory(path):
    target_url = f"{INVENTORY_SERVICE_URL}/api/movies"
    if path:
        target_url = f"{target_url}/{path}"
        
    headers = {key: value for key, value in request.headers if key.lower() != 'host'}
    
    try:
        resp = requests.request(
            method=request.method,
            url=target_url,
            headers=headers,
            params=request.args,       # Forwards query params like ?title=...
            data=request.get_data(),   # Forwards body JSON
            cookies=request.cookies,
            allow_redirects=False
        )
        excluded_headers = ['content-encoding', 'content-length', 'transfer-encoding', 'connection']
        resp_headers = [(name, value) for (name, value) in resp.raw.headers.items()
                        if name.lower() not in excluded_headers]
        
        # Preserves exact payload, HTTP status code, and headers
        return Response(resp.content, resp.status_code, resp_headers)
    except requests.exceptions.RequestException as e:
        return jsonify({"error": "Inventory service unavailable", "details": str(e)}), 503


# Billing RabbitMQ Queue Proxy
@gateway_bp.route('/api/billing', methods=['POST'])
@gateway_bp.route('/api/billing/', methods=['POST'])
def proxy_to_billing():
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 400

    data = request.get_json()
    required_fields = ["user_id", "number_of_items", "total_amount"]
    missing_fields = [field for field in required_fields if field not in data]
    
    if missing_fields:
        return jsonify({"error": f"Missing required fields: {', '.join(missing_fields)}"}), 400

    try:
        publish_to_rabbitmq(request.get_data())
        return jsonify({"message": "Message posted"}), 200
    except Exception as e:
        return jsonify({"error": "Failed to queue billing transaction", "details": str(e)}), 500
