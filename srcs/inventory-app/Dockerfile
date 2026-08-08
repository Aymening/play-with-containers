FROM debian:12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-venv \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create a small Python environment for the app.
RUN python3 -m venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH

WORKDIR /app

COPY srcs/inventory-app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Run the app as a normal user instead of root.
RUN useradd --create-home appuser
COPY --chown=appuser:appuser srcs/inventory-app/app ./app
COPY --chown=appuser:appuser srcs/inventory-app/server.py .
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=5s --timeout=5s --start-period=15s --retries=10 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=3)" || exit 1

CMD ["python", "server.py"]
