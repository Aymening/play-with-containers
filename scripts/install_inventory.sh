#!/usr/bin/env bash
set -e

export DEBIAN_FRONTEND=noninteractive

ENV_FILE="/vagrant/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Missing required environment file: $ENV_FILE" >&2
    exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

required_inventory_vars=(
    INVENTORY_DB_USER
    INVENTORY_DB_PASSWORD
    INVENTORY_DB_HOST
    INVENTORY_DB_PORT
    INVENTORY_DB_NAME
)

for variable_name in "${required_inventory_vars[@]}"; do
    if [[ -z "${!variable_name:-}" ]]; then
        echo "Missing required variable in $ENV_FILE: $variable_name" >&2
        exit 1
    fi
done

echo "==> Installing Inventory dependencies..."
sudo apt-get update -y

if dpkg-query -W -f='${Status}' libnode-dev 2>/dev/null | grep -q "install ok installed"; then
    sudo apt-get remove -y nodejs npm libnode-dev
fi

sudo apt-get install -y python3 python3-pip python3-venv postgresql postgresql-contrib curl ca-certificates

curl -fsSL https://deb.nodesource.com/setup_20.x -o /tmp/nodesource_setup.sh
sudo -E bash /tmp/nodesource_setup.sh
sudo apt-get install -y nodejs

VENV_DIR="/home/vagrant/.venvs/inventory"
sudo install -d -o vagrant -g vagrant /home/vagrant/.venvs
sudo -u vagrant python3 -m venv "$VENV_DIR"
sudo -u vagrant "$VENV_DIR/bin/python" -m pip install --upgrade pip
sudo -u vagrant "$VENV_DIR/bin/python" -m pip install -r /vagrant/srcs/inventory-app/requirements.txt

sudo systemctl start postgresql
sudo systemctl enable postgresql

sudo -u postgres psql \
    --set=db_user="$INVENTORY_DB_USER" \
    --set=db_password="$INVENTORY_DB_PASSWORD" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN', :'db_user')
WHERE NOT EXISTS (
    SELECT 1 FROM pg_roles WHERE rolname = :'db_user'
) \gexec

SELECT format('ALTER ROLE %I WITH PASSWORD %L', :'db_user', :'db_password') \gexec
SQL

sudo -u postgres psql \
    --set=db_name="$INVENTORY_DB_NAME" \
    --set=db_user="$INVENTORY_DB_USER" <<'SQL'
SELECT format('CREATE DATABASE %I OWNER %I', :'db_name', :'db_user')
WHERE NOT EXISTS (
    SELECT 1 FROM pg_database WHERE datname = :'db_name'
) \gexec
SQL

sudo -u postgres psql -d "$INVENTORY_DB_NAME" \
    --set=db_user="$INVENTORY_DB_USER" <<'SQL'
SELECT format('GRANT ALL PRIVILEGES ON SCHEMA public TO %I', :'db_user') \gexec
SELECT format('GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO %I', :'db_user') \gexec
SELECT format('GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO %I', :'db_user') \gexec
SELECT format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO %I', :'db_user') \gexec
SELECT format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO %I', :'db_user') \gexec
SQL

# Allow remote connections from gateway VM
PG_CONF=$(sudo find /etc/postgresql/ -name "postgresql.conf")
PG_HBA=$(sudo find /etc/postgresql/ -name "pg_hba.conf")

sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" "$PG_CONF"
PG_HBA_RULE="host    $INVENTORY_DB_NAME    $INVENTORY_DB_USER    192.168.56.0/24    md5"
sudo grep -Fqx "$PG_HBA_RULE" "$PG_HBA" || echo "$PG_HBA_RULE" | sudo tee -a "$PG_HBA"
sudo systemctl restart postgresql

sudo npm install -g --prefix /usr/local pm2@7.0.3

PM2_BIN=$(command -v pm2)
sudo -u vagrant env HOME=/home/vagrant "$PM2_BIN" update
sudo env PATH="$PATH:/usr/bin:/usr/local/bin" "$PM2_BIN" startup systemd -u vagrant --hp /home/vagrant
sudo -u vagrant env HOME=/home/vagrant "$PM2_BIN" start /vagrant/ecosystem.config.js --only inventory-app
sudo -u vagrant env HOME=/home/vagrant "$PM2_BIN" save

echo "==> Provisioning complete for Inventory VM."
