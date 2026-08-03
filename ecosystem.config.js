module.exports = {
  apps: [
    {
      name: "api-gateway",
      script: "srcs/api-gateway-app/server.py",
      interpreter: "/home/vagrant/.venvs/api-gateway/bin/python3",
      cwd: "/vagrant"
    },
    {
      name: "billing_app",
      script: "srcs/billing-app/server.py", 
      interpreter: "/home/vagrant/.venvs/billing/bin/python3",
      cwd: "/vagrant"
    },
    {
      name: "inventory-app",
      script: "srcs/inventory-app/server.py", 
      interpreter: "/home/vagrant/.venvs/inventory/bin/python3",
      cwd: "/vagrant"
    }
  ]
};
