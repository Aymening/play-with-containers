import os
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from dotenv import load_dotenv

load_dotenv()

def required_environment(name):
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required Billing database configuration: {name}")
    return value


DB_USER = required_environment("BILLING_DB_USER")
DB_PASS = required_environment("BILLING_DB_PASS")
DB_HOST = required_environment("BILLING_DB_HOST")
DB_PORT = required_environment("BILLING_DB_PORT")
DB_NAME = required_environment("BILLING_DB_NAME")

DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()
