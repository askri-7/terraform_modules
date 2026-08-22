#!/bin/bash
set -e

#################################
# Versions
#################################
NODE_MAJOR_VERSION="24"

#################################
# System update
#################################
echo "[+] Updating system..."
apt-get update
apt-get upgrade -y

#################################
# Install Docker + Docker Compose plugin
#################################
echo "[+] Installing Docker..."
apt-get install -y ca-certificates curl gnupg lsb-release
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

#################################
# Install Node.js (for frontend build)
#################################
echo "[+] Installing Node.js $${NODE_MAJOR_VERSION}..."
curl -fsSL https://deb.nodesource.com/setup_$${NODE_MAJOR_VERSION}.x | bash -
apt-get install -y nodejs

#################################
# Install Nginx + Certbot
#################################
echo "[+] Installing Nginx + Certbot..."
apt-get install -y nginx certbot python3-certbot-nginx
systemctl enable nginx

#################################
# Install Azure CLI (to fetch secrets from Key Vault)
#################################
echo "[+] Installing Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

#################################
# Mount data disk for PostgreSQL persistence
#################################
echo "[+] Checking for data disk..."
DATA_DISK=$(lsblk -dpno NAME,SIZE,TYPE | grep disk | grep -v "$(df / | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//')" | awk '{print $1}' | tail -1)

if [ -z "$DATA_DISK" ]; then
    echo "WARNING: No data disk found. Using OS disk for data."
else
    echo "[+] Data disk found: $DATA_DISK. Formatting and mounting..."
    mkfs -t ext4 "$DATA_DISK" 2>/dev/null || true
    mkdir -p /var/lib/docker/volumes/postgres_data
    mkdir -p /var/lib/docker/volumes/redis_data
    mount "$DATA_DISK" /var/lib/docker/volumes/postgres_data
    echo "$DATA_DISK /var/lib/docker/volumes/postgres_data ext4 defaults,nofail 0 2" >> /etc/fstab
    chown -R 999:999 /var/lib/docker/volumes/postgres_data
    echo "[+] Data disk mounted."
fi

#################################
# Clone application repository
#################################
echo "[+] Cloning application..."
APP_DIR="/opt/secure-login-demo"
mkdir -p $${APP_DIR}
cd $${APP_DIR}
git clone -b ${app_branch} ${app_repo_url} .

#################################
# Build frontend (served by native Nginx)
#################################
echo "[+] Building frontend..."
cd $${APP_DIR}/frontend
npm ci
export VITE_API_URL="/api"
npm run build

echo "[+] Deploying frontend to Nginx webroot..."
rm -rf /usr/share/nginx/html/*
cp -r $${APP_DIR}/frontend/dist/* /usr/share/nginx/html/
chown -R www-data:www-data /usr/share/nginx/html

##################################
# Fetch db-password from Key Vault (VM managed identity)
#################################
echo "[+] Fetching database password from Key Vault..."
export POSTGRES_PASSWORD=$(az keyvault secret show \
  --name db-password \
  --vault-name ${key_vault_name} \
  --query value -o tsv)

#################################
# Write Docker Compose environment file (NON-SENSITIVE ONLY)
#################################
echo "[+] Writing Docker Compose environment..."
cat > $${APP_DIR}/.env <<ENVFILE
AZURE_KEY_VAULT_URL=${key_vault_url}
FRONTEND_URL=${frontend_url}
API_URL=${api_url}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_POOL_MAX=${db_pool_max}
DB_TIMEOUT=${db_timeout}
DB_IDLE_TIMEOUT=${db_idle_timeout}
DB_STATEMENT_TIMEOUT=${db_statement_timeout}
GITHUB_CLIENT_ID=${github_client_id}
GITHUB_CALLBACK_URL=${github_callback_url}
GOOGLE_CLIENT_ID=${google_client_id}
GOOGLE_CALLBACK_URL=${google_callback_url}
SMTP_HOST=${smtp_host}
SMTP_PORT=${smtp_port}
SMTP_FROM=${smtp_from}
ENVFILE

chmod 600 $${APP_DIR}/.env
#################################
# Configure Nginx (HTTP first — Certbot adds SSL after)
#################################
echo "[+] Configuring Nginx..."
cat > /etc/nginx/sites-available/default <<'NGINX'
server {
    listen 80;
    server_name ${domain_name};

    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:${app_port}/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    location /health {
        proxy_pass http://127.0.0.1:${app_port};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
NGINX

nginx -t
systemctl start nginx

#################################
# Obtain SSL certificate (Let's Encrypt)
#################################
echo "[+] Obtaining SSL certificate for ${domain_name}..."
sleep 15

certbot --nginx \
  -d ${domain_name} \
  --non-interactive \
  --agree-tos \
  --email ${admin_email} \
  --redirect \
  || echo "WARNING: Certbot failed. SSL not configured."

#################################
# Build backend image & start stack
#################################
echo "[+] Building backend image..."
cd $${APP_DIR}
docker compose -f docker-compose.prod.yml build backend

echo "[+] Starting production stack..."
docker compose -f docker-compose.prod.yml up -d

#################################
# Clean up cloud-init artifacts
#################################
echo "[+] Cleaning up cloud-init logs..."
shred -u /var/lib/cloud/instance/user-data.txt 2>/dev/null || true
shred -u /var/log/cloud-init.log 2>/dev/null || true
shred -u /var/log/cloud-init-output.log 2>/dev/null || true

#################################
# Final status
#################################
echo "================================"
echo " Deployment Complete"
echo "================================"
echo "Domain: https://${domain_name}"
echo "Health: https://${domain_name}/health/live"
docker compose -f docker-compose.prod.yml ps
