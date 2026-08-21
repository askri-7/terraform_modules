#!/bin/bash

set -e


NODE_VERSION="22"


apt update -y
apt upgrade -y


apt install -y \
    nginx \
    git \
    curl \
    wget \
    unzip \
    vim \
    net-tools


curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -

apt install -y nodejs


systemctl enable nginx
systemctl start nginx

