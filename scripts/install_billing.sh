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

required_billing_vars=(
    BILLING_DB_USER
    BILLING_DB_PASS
    BILLING_DB_NAME
    BILLING_DB_HOST
    BILLING_DB_PORT
    RABBITMQ_HOST
    RABBITMQ_PORT
    RABBITMQ_USER
    RABBITMQ_PASS
    RABBITMQ_QUEUE
)

for variable_name in "${required_billing_vars[@]}"; do
    if [[ -z "${!variable_name:-}" ]]; then
        echo "Missing required variable in $ENV_FILE: $variable_name" >&2
        exit 1
    fi
done

echo "==> Updating package indices..."
sudo apt-get update -y

if dpkg-query -W -f='${Status}' libnode-dev 2>/dev/null | grep -q "install ok installed"; then
    sudo apt-get remove -y nodejs npm libnode-dev
fi

sudo apt-get install -y python3 python3-pip python3-venv postgresql postgresql-contrib rabbitmq-server curl ca-certificates

curl -fsSL https://deb.nodesource.com/setup_20.x -o /tmp/nodesource_setup.sh
sudo -E bash /tmp/nodesource_setup.sh
sudo apt-get install -y nodejs

VENV_DIR="/home/vagrant/.venvs/billing"
sudo install -d -o vagrant -g vagrant /home/vagrant/.venvs
sudo -u vagrant python3 -m venv "$VENV_DIR"
sudo -u vagrant "$VENV_DIR/bin/python" -m pip install --upgrade pip
sudo -u vagrant "$VENV_DIR/bin/python" -m pip install -r /vagrant/srcs/billing-app/requirements.txt

echo "==> Configuring PostgreSQL for Billing..."
sudo systemctl start postgresql
sudo systemctl enable postgresql

sudo -u postgres psql \
    --set=db_user="$BILLING_DB_USER" \
    --set=db_password="$BILLING_DB_PASS" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN', :'db_user')
WHERE NOT EXISTS (
    SELECT 1 FROM pg_roles WHERE rolname = :'db_user'
) \gexec

SELECT format('ALTER ROLE %I WITH PASSWORD %L', :'db_user', :'db_password') \gexec
SQL

sudo -u postgres psql \
    --set=db_name="$BILLING_DB_NAME" \
    --set=db_user="$BILLING_DB_USER" <<'SQL'
SELECT format('CREATE DATABASE %I OWNER %I', :'db_name', :'db_user')
WHERE NOT EXISTS (
    SELECT 1 FROM pg_database WHERE datname = :'db_name'
) \gexec
SQL

sudo -u postgres psql -d "$BILLING_DB_NAME" \
    --set=db_user="$BILLING_DB_USER" <<'SQL'
SELECT format('GRANT ALL PRIVILEGES ON SCHEMA public TO %I', :'db_user') \gexec
SELECT format('GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO %I', :'db_user') \gexec
SELECT format('GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO %I', :'db_user') \gexec
SELECT format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO %I', :'db_user') \gexec
SELECT format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO %I', :'db_user') \gexec
SQL

# Allow PostgreSQL remote connections across Vagrant subnet
PG_CONF=$(sudo find /etc/postgresql/ -name "postgresql.conf")
PG_HBA=$(sudo find /etc/postgresql/ -name "pg_hba.conf")

sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" "$PG_CONF"
PG_HBA_RULE="host    $BILLING_DB_NAME    $BILLING_DB_USER    192.168.56.0/24    md5"
sudo grep -Fqx "$PG_HBA_RULE" "$PG_HBA" || echo "$PG_HBA_RULE" | sudo tee -a "$PG_HBA"
sudo systemctl restart postgresql

echo "==> Configuring RabbitMQ..."
sudo systemctl start rabbitmq-server
sudo systemctl enable rabbitmq-server
sudo rabbitmq-plugins enable rabbitmq_management || true

if sudo rabbitmqctl list_users -q | awk -v user="$RABBITMQ_USER" '$1 == user { found = 1 } END { exit !found }'; then
    sudo rabbitmqctl change_password "$RABBITMQ_USER" "$RABBITMQ_PASS"
else
    sudo rabbitmqctl add_user "$RABBITMQ_USER" "$RABBITMQ_PASS"
fi
sudo rabbitmqctl set_user_tags "$RABBITMQ_USER" administrator
sudo rabbitmqctl set_permissions -p "/" "$RABBITMQ_USER" ".*" ".*" ".*"
sudo bash -c 'echo "loopback_users.guest = true" > /etc/rabbitmq/rabbitmq.conf'
sudo systemctl restart rabbitmq-server

echo "==> Installing PM2 process manager..."
sudo npm install -g --prefix /usr/local pm2@7.0.3

PM2_BIN=$(command -v pm2)

# The audit manages Billing with `sudo pm2 ...`, so Billing is the only process
# managed by root PM2. Remove the legacy vagrant-owned process to prevent two
# consumers from reading the same queue.
sudo -u vagrant env HOME=/home/vagrant "$PM2_BIN" delete billing-worker || true
sudo -u vagrant env HOME=/home/vagrant "$PM2_BIN" save --force || true
sudo -u vagrant env HOME=/home/vagrant "$PM2_BIN" kill || true
sudo systemctl disable --now pm2-vagrant || true

sudo env HOME=/root PATH="$PATH:/usr/bin:/usr/local/bin" \
    "$PM2_BIN" startup systemd -u root --hp /root
sudo env HOME=/root "$PM2_BIN" delete billing_app || true
sudo env HOME=/root "$PM2_BIN" start /vagrant/ecosystem.config.js --only billing_app
sudo env HOME=/root "$PM2_BIN" save --force

echo "==> Provisioning complete for Billing VM."
