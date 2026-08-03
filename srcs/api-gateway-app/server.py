import os
from app import create_app

app = create_app()

if __name__ == '__main__':
    # Defaults to 5002 per project specifications
    port = int(os.getenv("GATEWAY_PORT", 5002))
    app.run(host='0.0.0.0', port=port, debug=False)
