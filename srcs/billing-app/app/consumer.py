import os
import json
import time
from decimal import Decimal
import pika
from dotenv import load_dotenv
from app.database import SessionLocal, Base, engine
from app.models import Order

load_dotenv()

def required_environment(name):
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required RabbitMQ configuration: {name}")
    return value


RABBITMQ_HOST = required_environment("RABBITMQ_HOST")
RABBITMQ_PORT = int(required_environment("RABBITMQ_PORT"))
RABBITMQ_USER = required_environment("RABBITMQ_USER")
RABBITMQ_PASS = required_environment("RABBITMQ_PASS")
RABBITMQ_QUEUE = required_environment("RABBITMQ_QUEUE")


def init_db():
    """Ensure database tables exist before consuming messages."""
    Base.metadata.create_all(bind=engine)


def process_message(ch, method, properties, body):
    """Callback triggered whenever a message is received from RabbitMQ."""
    session = SessionLocal()
    try:
        data = json.loads(body.decode('utf-8'))
        print(f" [x] Received order message: {data}")

        # Extract values
        user_id = str(data.get("user_id"))
        number_of_items = int(data["number_of_items"])
        total_amount = Decimal(str(data["total_amount"]))

        # Save to database
        new_order = Order(
            user_id=user_id,
            number_of_items=number_of_items,
            total_amount=total_amount
        )
        session.add(new_order)
        session.commit()
        print(" [✓] Order successfully inserted into orders table.")

        # Manual Acknowledgement: Notify RabbitMQ to remove message from queue
        ch.basic_ack(delivery_tag=method.delivery_tag)

    except Exception as e:
        print(f" [!] Error processing message: {e}")
        session.rollback()
        # Nack without requeue if malformed, or requeue depending on design choice
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
    finally:
        session.close()


def start_consumer():
    """Starts listening to RabbitMQ and consumes all pending & new messages."""
    init_db()
    
    credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASS)
    parameters = pika.ConnectionParameters(
        host=RABBITMQ_HOST,
        port=RABBITMQ_PORT,
        credentials=credentials,
        heartbeat=600
    )

    # Retry mechanism in case RabbitMQ is booting up
    while True:
        try:
            connection = pika.BlockingConnection(parameters)
            break
        except pika.exceptions.AMQPConnectionError:
            print(" [!] RabbitMQ not ready yet, retrying in 5 seconds...")
            time.sleep(5)

    channel = connection.channel()
    channel.queue_declare(queue=RABBITMQ_QUEUE, durable=True)

    # Ensure consumer gets one message at a time to guarantee safe processing
    channel.basic_qos(prefetch_count=1)

    channel.basic_consume(
        queue=RABBITMQ_QUEUE,
        on_message_callback=process_message,
        auto_ack=False  # Explicit manual acknowledgment
    )

    print(f" [*] Billing API service started. Waiting for messages in '{RABBITMQ_QUEUE}'...")
    try:
        channel.start_consuming()
    except KeyboardInterrupt:
        print(" [x] Stopping Billing Consumer...")
        channel.stop_consuming()
        connection.close()
