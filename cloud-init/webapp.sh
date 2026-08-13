#!/bin/bash

set -e

#################################
# Versions
#################################
NODE_MAJOR_VERSION="24"
POSTGRES_VERSION="16"

#################################
# System update
#################################
echo "[+] Updating system..."
apt-get update
apt-get upgrade -y

#################################
# Dependencies
#################################
echo "[+] Installing dependencies..."
apt-get install -y \
  curl gnupg ca-certificates lsb-release \
  software-properties-common wget git build-essential

#################################
# Install Nginx
#################################
echo "[+] Installing Nginx..."
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx

#################################
# Install Node.js
#################################
echo "[+] Installing Node.js $${NODE_MAJOR_VERSION}..."
curl -fsSL https://deb.nodesource.com/setup_$${NODE_MAJOR_VERSION}.x | bash -
apt-get install -y nodejs
npm install -g pm2

#################################
# Install PostgreSQL
#################################
echo "[+] Installing PostgreSQL $${POSTGRES_VERSION}..."
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg
echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
  > /etc/apt/sources.list.d/postgresql.list
apt-get update
apt-get install -y postgresql-$${POSTGRES_VERSION} postgresql-client-$${POSTGRES_VERSION}
systemctl enable postgresql
systemctl start postgresql

#################################
# Configure PostgreSQL
#################################
echo "[+] Configuring PostgreSQL..."

# Create DB user and database
sudo -u postgres psql <<EOF
CREATE USER ${db_user} WITH PASSWORD '__DB_PASS_PLACEHOLDER__';
CREATE DATABASE ${db_name} OWNER ${db_user};
GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};
ALTER ROLE ${db_user} CREATEDB;
EOF

cat > /etc/postgresql/$${POSTGRES_VERSION}/main/conf.d/99-custom.conf <<'PGCONF'
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 16MB
maintenance_work_mem = 128MB
max_connections = 50
PGCONF

systemctl restart postgresql

#################################
# Mount Data Disk
#################################
echo "[+] Mounting data disk..."
DATA_DISK=$(lsblk -dpno NAME,SIZE,TYPE | grep disk | awk '{print $1}' | tail -1)
mkdir -p /data
mkfs -t ext4 $${DATA_DISK} || true
mount $${DATA_DISK} /data || true
echo "$${DATA_DISK} /data ext4 defaults,nofail 0 2" >> /etc/fstab

systemctl stop postgresql
mkdir -p /data/postgresql
cp -a /var/lib/postgresql/$${POSTGRES_VERSION}/main /data/postgresql/
rm -rf /var/lib/postgresql/$${POSTGRES_VERSION}/main
ln -s /data/postgresql/main /var/lib/postgresql/$${POSTGRES_VERSION}/main
chown -R postgres:postgres /data/postgresql
systemctl start postgresql

#################################
# Clone & Setup App
#################################
echo "[+] Cloning application..."
APP_DIR="/opt/secure-login-demo"
mkdir -p $${APP_DIR}
cd $${APP_DIR}

git clone -b ${app_branch} ${app_repo_url} .
cd backend

#################################
# Write .env File (with real secrets)
#################################
echo "[+] Writing environment configuration..."
cat > $${APP_DIR}/backend/.env <<'ENVFILE'
NODE_ENV=${node_env}
PORT=${app_port}
FRONTEND_URL=${frontend_url}

DATABASE_URL=postgresql://${db_user}:${db_password}@localhost:5432/${db_name}
DB_POOL_MAX=${db_pool_max}
DB_TIMEOUT=${db_timeout}
DB_IDLE_TIMEOUT=${db_idle_timeout}
DB_STATEMENT_TIMEOUT=${db_statement_timeout}

JWT_SECRET=${jwt_secret}
ADMIN_EMAIL=${admin_email}
ADMIN_PASSWORD=${admin_password}

GITHUB_CLIENT_ID=${github_client_id}
GITHUB_CLIENT_SECRET=${github_client_secret}
GITHUB_CALLBACK_URL=${github_callback_url}

GOOGLE_CLIENT_ID=${google_client_id}
GOOGLE_CLIENT_SECRET=${google_client_secret}
GOOGLE_CALLBACK_URL=${google_callback_url}
ENVFILE

chmod 600 $${APP_DIR}/backend/.env
chown root:root $${APP_DIR}/backend/.env

#################################
# Build & Deploy App
#################################
echo "[+] Installing dependencies..."
npm ci

echo "[+] Generating Prisma client..."
npx prisma generate

echo "[+] Running database migrations..."
npx prisma migrate deploy

echo "[+] Seeding admin account..."
npx prisma db seed

echo "[+] Building application..."
npm run build

#################################
# Configure Nginx
#################################
echo "[+] Configuring Nginx..."
cat > /etc/nginx/sites-available/default <<'NGINX'
server {
    listen 80;
    server_name _;

    location /api/ {
        proxy_pass http://127.0.0.1:${app_port}/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    location /health {
        proxy_pass http://127.0.0.1:${app_port};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
}
NGINX

nginx -t
systemctl reload nginx

#################################
# Start App with PM2
#################################
echo "[+] Starting application with PM2..."
cd $${APP_DIR}/backend
pm2 start dist/main.js --name "secure-login-demo" -- --port ${app_port}
pm2 startup systemd -u root --hp /root
pm2 save

#################################
# Clean Up
#################################
echo "[+] Cleaning up cloud-init logs..."
shred -u /var/lib/cloud/instance/user-data.txt 2>/dev/null || true
shred -u /var/log/cloud-init.log 2>/dev/null || true
shred -u /var/log/cloud-init-output.log 2>/dev/null || true

#################################
# Final Status
#################################
echo "================================"
echo " Deployment Complete"
echo "================================"
echo "App: $${APP_DIR}"
echo "DB: postgresql://${db_user}:****@localhost:5432/${db_name}"
echo "Health: http://$(curl -s ifconfig.me)/health/live"
pm2 status

