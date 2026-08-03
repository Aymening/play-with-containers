#!/usr/bin/env bash
set -e

export DEBIAN_FRONTEND=noninteractive

echo "==> Installing Gateway dependencies..."
sudo apt-get update -y

if dpkg-query -W -f='${Status}' libnode-dev 2>/dev/null | grep -q "install ok installed"; then
    sudo apt-get remove -y nodejs npm libnode-dev
fi

sudo apt-get install -y python3 python3-pip python3-venv curl ca-certificates

curl -fsSL https://deb.nodesource.com/setup_20.x -o /tmp/nodesource_setup.sh
sudo -E bash /tmp/nodesource_setup.sh
sudo apt-get install -y nodejs

VENV_DIR="/home/vagrant/.venvs/api-gateway"
sudo install -d -o vagrant -g vagrant /home/vagrant/.venvs
sudo -u vagrant python3 -m venv "$VENV_DIR"
sudo -u vagrant "$VENV_DIR/bin/python" -m pip install --upgrade pip
sudo -u vagrant "$VENV_DIR/bin/python" -m pip install -r /vagrant/srcs/api-gateway-app/requirements.txt

sudo npm install -g --prefix /usr/local pm2@7.0.3

PM2_BIN=$(command -v pm2)
sudo -u vagrant env HOME=/home/vagrant "$PM2_BIN" update
sudo env PATH="$PATH:/usr/bin:/usr/local/bin" "$PM2_BIN" startup systemd -u vagrant --hp /home/vagrant
sudo -u vagrant env HOME=/home/vagrant "$PM2_BIN" start /vagrant/ecosystem.config.js --only api-gateway
sudo -u vagrant env HOME=/home/vagrant "$PM2_BIN" save

echo "==> Provisioning complete for Gateway VM."
