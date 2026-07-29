#!/bin/bash

set -e  # stop if any command fails

#################################
# Versions - customize here
#################################

NGINX_VERSION="1.24.0"
NODE_MAJOR_VERSION="22"
POSTGRES_VERSION="16"
REDIS_VERSION="7"

#################################
# System update
#################################

echo "[+] Updating system..."

apt-get update
apt-get upgrade -y

#################################
# Common dependencies
#################################

echo "[+] Installing dependencies..."

apt-get install -y \
    curl \
    gnupg \
    ca-certificates \
    lsb-release \
    software-properties-common \
    wget \
    git


#################################
# Install Nginx
#################################

echo "[+] Installing Nginx..."

apt-get install -y nginx

systemctl enable nginx
systemctl start nginx

echo "Nginx installed:"
nginx -v


#################################
# Install Node.js
#################################

echo "[+] Installing Node.js ${NODE_MAJOR_VERSION}..."

curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR_VERSION}.x | bash -

apt-get install -y nodejs

echo "Node installed:"
node -v
npm -v


#################################
# Install PostgreSQL
#################################

echo "[+] Installing PostgreSQL ${POSTGRES_VERSION}..."

curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | gpg --dearmor \
    -o /usr/share/keyrings/postgresql.gpg


echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] \
http://apt.postgresql.org/pub/repos/apt \
$(lsb_release -cs)-pgdg main" \
> /etc/apt/sources.list.d/postgresql.list


apt-get update

apt-get install -y \
    postgresql-${POSTGRES_VERSION} \
    postgresql-client-${POSTGRES_VERSION}


systemctl enable postgresql
systemctl start postgresql


echo "PostgreSQL installed:"
psql --version


#################################
# Install Redis
#################################

echo "[+] Installing Redis..."

apt-get install -y redis-server


systemctl enable redis-server
systemctl start redis-server


echo "Redis installed:"
redis-server --version


#################################
# Final status
#################################

echo "================================"
echo " Installation completed"
echo "================================"

systemctl --no-pager status nginx | head
systemctl --no-pager status postgresql | head
systemctl --no-pager status redis-server | head