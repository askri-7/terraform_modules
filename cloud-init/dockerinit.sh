#!/bin/bash
set -e

APP_DIR="/opt/secure-login-demo"

#################################
# Install Docker + Compose plugin
#################################
echo "[+] Installing Docker..."
apt-get update
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable docker

#################################
# Install Nginx + Certbot
#################################
echo "[+] Installing Nginx + Certbot..."
apt-get install -y nginx certbot python3-certbot-nginx
systemctl enable nginx

#################################
# Mount data disk
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
# Setup app directory
#################################
echo "[+] Setting up application directory..."
mkdir -p "$${APP_DIR}"
cd "$${APP_DIR}"

#################################
# Write Docker Compose .env file
#################################
echo "[+] Writing Docker Compose environment..."
cat > "$${APP_DIR}/.env" <<EOF
DOCKERHUB_USERNAME=${dockerhub_username}
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
ADMIN_EMAIL=${admin_email}
ADMIN_PASSWORD=${admin_password}
POSTGRES_PASSWORD=${db_password}
EOF
chmod 644 "$${APP_DIR}/.env"
#################################
# Write docker-compose.prod.yml
#################################
echo "[+] Writing docker-compose.prod.yml..."
cat > "$${APP_DIR}/docker-compose.prod.yml" <<COMPOSE
services:
  frontend:
    image: ${dockerhub_username}/secure-login-demo-frontend:latest
    restart: unless-stopped
    ports:
      - "127.0.0.1:8080:80"
    environment:
      BACKEND_HOST: backend
      BACKEND_PORT: "3000"
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://127.0.0.1/"]
      interval: 30s
      timeout: 5s
      start_period: 10s
      retries: 3

  backend:
    image: ${dockerhub_username}/secure-login-demo-backend:latest
    restart: unless-stopped
    ports:
      - "127.0.0.1:3000:3000"
    environment:
      AZURE_KEY_VAULT_URL: $${AZURE_KEY_VAULT_URL}
      NODE_ENV: production
      PORT: 3000
      FRONTEND_URL: $${FRONTEND_URL}
      API_URL: $${API_URL}
      DB_HOST: db
      DB_PORT: 5432
      DB_NAME: $${DB_NAME}
      DB_POOL_MAX: $${DB_POOL_MAX}
      DB_TIMEOUT: $${DB_TIMEOUT}
      DB_IDLE_TIMEOUT: $${DB_IDLE_TIMEOUT}
      DB_STATEMENT_TIMEOUT: $${DB_STATEMENT_TIMEOUT}
      REDIS_HOST: redis
      REDIS_PORT: 6379
      GITHUB_CLIENT_ID: $${GITHUB_CLIENT_ID}
      GITHUB_CALLBACK_URL: $${GITHUB_CALLBACK_URL}
      GOOGLE_CLIENT_ID: $${GOOGLE_CLIENT_ID}
      GOOGLE_CALLBACK_URL: $${GOOGLE_CALLBACK_URL}
      SMTP_HOST: $${SMTP_HOST}
      SMTP_PORT: $${SMTP_PORT}
      SMTP_FROM: $${SMTP_FROM}
      ADMIN_EMAIL: $${ADMIN_EMAIL}
      ADMIN_PASSWORD: $${ADMIN_PASSWORD}
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get({host:'127.0.0.1',port:process.env.PORT||3000,path:'/health/live',timeout:3000},r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"]
      interval: 30s
      timeout: 5s
      start_period: 30s
      retries: 3

  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: $${DB_USER}
      POSTGRES_PASSWORD: $${POSTGRES_PASSWORD}
      POSTGRES_DB: $${DB_NAME}
    volumes:
      - /var/lib/docker/volumes/postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \\$\\$POSTGRES_USER -d \\$\\$POSTGRES_DB"]
      interval: 5s
      timeout: 5s
      retries: 5
      start_period: 10s

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    volumes:
      - /var/lib/docker/volumes/redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
COMPOSE

#################################
# Delete secrets from shell memory
#################################
echo "[+] Clearing secrets from shell..."
unset POSTGRES_PASSWORD ADMIN_EMAIL ADMIN_PASSWORD

#################################
# Configure Nginx
#################################
echo "[+] Configuring Nginx..."
cat > /etc/nginx/sites-available/default <<NGINX
server {
    listen 80;
    server_name ${domain_name};

    location / {
        proxy_pass http://127.0.0.1:8080/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:${app_port}/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    location /health {
        proxy_pass http://127.0.0.1:${app_port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
NGINX

nginx -t
systemctl start nginx

#################################
# Obtain SSL certificate
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
# Try to pull and start stack
# If images don't exist yet (first boot), this is expected.
# The app CI/CD pipeline will deploy them later.
#################################
echo "[+] Attempting to pull images from DockerHub..."
cd "$${APP_DIR}"
docker compose -f docker-compose.prod.yml pull || echo "WARNING: Images not found on DockerHub yet. App CI/CD will deploy them."

echo "[+] Attempting to start stack..."
docker compose -f docker-compose.prod.yml up -d || echo "WARNING: Could not start stack. Waiting for first deployment from app CI/CD."

#################################
# Clean up
#################################
echo "[+] Cleaning up cloud-init logs..."
shred -u /var/lib/cloud/instance/user-data.txt 2>/dev/null || true
shred -u /var/log/cloud-init.log 2>/dev/null || true
shred -u /var/log/cloud-init-output.log 2>/dev/null || true

#################################
# Final status
#################################
echo "================================"
echo " VM Bootstrap Complete"
echo "================================"
echo "Domain: https://${domain_name}"
echo "Status: Waiting for app deployment from CI/CD"
echo "Run: docker compose -f /opt/secure-login-demo/docker-compose.prod.yml up -d"
docker compose -f docker-compose.prod.yml ps 2>/dev/null || echo "No containers running yet."
