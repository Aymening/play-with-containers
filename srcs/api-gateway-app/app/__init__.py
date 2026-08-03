from flask import Flask
from dotenv import load_dotenv

load_dotenv()

def create_app():
    app = Flask(__name__)

    # Import routes only after the shared .env file has been loaded.
    from app.routes import gateway_bp
    app.register_blueprint(gateway_bp)

    return app
