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

#################################
# Install Certbot (for free SSL)
#################################
echo "[+] Installing Certbot..."
apt-get install -y certbot python3-certbot-nginx

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

sudo -u postgres psql <<'EOF'
CREATE USER ${db_user} WITH PASSWORD '${db_password}';
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
# Mount Data Disk (idempotent)
#################################
echo "[+] Checking data disk..."

# Find the data disk (not the OS disk /dev/sda)
DATA_DISK=$(lsblk -dpno NAME,SIZE,TYPE | grep disk | grep -v "$(df / | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//')" | awk '{print $1}' | tail -1)

if [ -z "$DATA_DISK" ]; then
    echo "WARNING: No data disk found. Using OS disk for PostgreSQL data."
    mkdir -p /data
else
    echo "[+] Data disk found: $DATA_DISK"
    mkdir -p /data
    
    # Only format if not already has a filesystem
    if ! blkid "$DATA_DISK" > /dev/null 2>&1; then
        echo "[+] Formatting data disk..."
        mkfs -t ext4 "$DATA_DISK"
    else
        echo "[+] Data disk already formatted, skipping mkfs."
    fi
    
    # Only add to fstab if not already there
    if ! grep -q "$DATA_DISK" /etc/fstab; then
        echo "$DATA_DISK /data ext4 defaults,nofail 0 2" >> /etc/fstab
        echo "[+] Added to /etc/fstab."
    fi
    
    # Mount (idempotent — safe to run multiple times)
    mount "$DATA_DISK" /data || true
fi

#################################
# Move PostgreSQL data to data disk (idempotent)
#################################
echo "[+] Setting up PostgreSQL on data disk..."

PG_DATA_DIR="/data/postgresql"
PG_LINK="/var/lib/postgresql/$${POSTGRES_VERSION}/main"

# Only move if not already moved
if [ ! -L "$PG_LINK" ] || [ "$(readlink -f "$PG_LINK")" != "$PG_DATA_DIR" ]; then
    systemctl stop postgresql
    
    mkdir -p "$PG_DATA_DIR"
    
    # Only copy if data dir is empty
    if [ -z "$(ls -A "$PG_DATA_DIR" 2>/dev/null)" ]; then
        echo "[+] Copying PostgreSQL data..."
        cp -a /var/lib/postgresql/$${POSTGRES_VERSION}/main/* "$PG_DATA_DIR/" 2>/dev/null || true
    fi
    
    rm -rf "$PG_LINK"
    ln -s "$PG_DATA_DIR" "$PG_LINK"
    chown -R postgres:postgres /data/postgresql
    chmod 700 "$PG_DATA_DIR"
    
    systemctl start postgresql
    echo "[+] PostgreSQL data moved."
else
    echo "[+] PostgreSQL already on data disk, skipping."
fi
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
# Write .env File
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
# Build & Deploy Frontend
#################################
echo "[+] Building frontend..."
cd $${APP_DIR}/frontend

export VITE_API_URL="/api"
npm ci
npm run build

echo "[+] Deploying frontend to Nginx webroot..."
rm -rf /usr/share/nginx/html/*
cp -r $${APP_DIR}/frontend/dist/* /usr/share/nginx/html/
chown -R www-data:www-data /usr/share/nginx/html

#################################
# Prune build-only dependencies
#################################
echo "[+] Pruning devDependencies..."
cd $${APP_DIR}/backend
npm prune --omit=dev
rm -rf $${APP_DIR}/frontend/node_modules

#################################
# Configure Nginx (HTTP only first)
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
# Get SSL Certificate (Let's Encrypt)
#################################
echo "[+] Obtaining SSL certificate for ${domain_name}..."

# Wait for DNS to be ready
sleep 15

certbot --nginx \
  -d ${domain_name} \
  --non-interactive \
  --agree-tos \
  --email ${admin_email} \
  --redirect \
  || echo "WARNING: Certbot failed. SSL not configured. Run manually: sudo certbot --nginx -d ${domain_name}"

#################################
# Start App with PM2
#################################
echo "[+] Starting application with PM2..."
cd $${APP_DIR}/backend
pm2 start dist/src/main.js --name "secure-login-demo"
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
echo "Domain: https://${domain_name}"
echo "Health: https://${domain_name}/health/live"
pm2 status