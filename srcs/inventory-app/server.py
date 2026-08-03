from app import create_app

app = create_app()

if __name__ == "__main__":
    # Configured to run on Port 8080 as required by specification
    app.run(host="0.0.0.0", port=8080)