#!/bin/bash

set -e


NODE_VERSION="22"
PM2_VERSION="5.4.3"


apt update -y
apt upgrade -y


apt install -y \
    git \
    curl \
    wget \
    unzip \
    vim \
    build-essential \
    net-tools \
    postgresql-client \
    redis-tools


curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -

apt install -y nodejs


npm install -g pm2@${PM2_VERSION}


pm2 startup systemd -u root --hp /root || true

