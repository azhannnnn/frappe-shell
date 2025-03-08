#!/bin/bash

# Update and upgrade the system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y python3 python3-dev python3-pip python3-venv \
    curl git mariadb-client libmariadb-dev \
    redis supervisor cron nodejs npm \
    yarn wkhtmltopdf xvfb build-essential

# Download and install nvm:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# in lieu of restarting the shell
\. "$HOME/.nvm/nvm.sh"

# Download and install Node.js:
nvm install 18

sudo npm install -g yarn

# Install MariaDB Server
sudo apt install -y mariadb-server
sudo service mariadb start
sudo service mariadb enable

# Secure MariaDB installation
sudo mysql_secure_installation <<EOF
n
y
y
y
y
EOF

# Create Frappe Database User
sudo mysql -u root -p <<EOF
CREATE USER 'frappe'@'%' IDENTIFIED BY 'frappe_password';
GRANT ALL PRIVILEGES ON *.* TO 'frappe'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

# Modify MySQL bind address
sudo sed -i "s/bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/g" /etc/mysql/mariadb.conf.d/50-server.cnf
sudo service mariadb restart

# Disable Transparent Huge Pages (THP) for Redis
sudo bash -c 'echo never > /sys/kernel/mm/transparent_hugepage/enabled'
sudo bash -c 'echo never > /sys/kernel/mm/transparent_hugepage/defrag'
echo "if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
  echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
  echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi" | sudo tee -a /etc/rc.local

# Enable Redis Server
sudo service redis-server enable
sudo service redis-server start

# Install Frappe Bench
sudo pip3 install --upgrade pip
sudo pip3 install frappe-bench

# Create Frappe Directory
sudo mkdir -p /opt/frappe
sudo chown -R $USER:$USER /opt/frappe
cd /opt/frappe

# Initialize Bench
bench init --frappe-branch version-15 frappe-bench
cd frappe-bench

# Create a New Site
bench new-site site1.local --admin-password admin --db-root-username frappe --db-root-password frappe_password

# Bind Site to 0.0.0.0
sudo sed -i 's/"host_name":.*/"host_name": "0.0.0.0",/g' sites/common_site_config.json

# Fix Yarn/CSS build error
bench build

# Start the Bench
bench start

# Display Success Message
echo "Frappe has been successfully installed!"
echo "Access your site at: http://<YOUR-SERVER-IP>:8000"
