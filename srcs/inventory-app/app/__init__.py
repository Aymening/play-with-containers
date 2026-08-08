import os
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.engine import URL
from dotenv import load_dotenv

load_dotenv()

db = SQLAlchemy()

def create_app():
    app = Flask(__name__)

    required_variables = (
        'INVENTORY_DB_USER',
        'INVENTORY_DB_PASSWORD',
        'INVENTORY_DB_HOST',
        'INVENTORY_DB_PORT',
        'INVENTORY_DB_NAME',
    )
    missing_variables = [name for name in required_variables if not os.getenv(name)]
    if missing_variables:
        missing_names = ', '.join(missing_variables)
        raise RuntimeError(f'Missing required Inventory configuration: {missing_names}')

    user = os.environ['INVENTORY_DB_USER']
    password = os.environ['INVENTORY_DB_PASSWORD']
    host = os.environ['INVENTORY_DB_HOST']
    port = os.environ['INVENTORY_DB_PORT']
    db_name = os.environ['INVENTORY_DB_NAME']

    app.config['SQLALCHEMY_DATABASE_URI'] = URL.create(
        drivername='postgresql+psycopg2',
        username=user,
        password=password,
        host=host,
        port=int(port),
        database=db_name,
    )
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

    db.init_app(app)

    with app.app_context():
        # Automatically create tables on startup
        from . import models
        db.create_all()

        # IMPORT ROUTES HERE so Flask registers the @app.route decorators!
        from . import routes

    return app
