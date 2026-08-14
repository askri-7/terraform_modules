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
# Install Certbot
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

#################################
# Start PostgreSQL & wait for it
#################################
echo "[+] Starting PostgreSQL..."
systemctl start postgresql

for i in {1..30}; do
  if pg_isready -q; then
    echo "[+] PostgreSQL is ready."
    break
  fi
  echo "  ...waiting for PostgreSQL ($i/30)"
  sleep 1
done

if ! pg_isready -q; then
  echo "ERROR: PostgreSQL failed to start initially"
  journalctl -u postgresql -n 50
  exit 1
fi

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
listen_addresses = 'localhost'
port = 5432
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 16MB
maintenance_work_mem = 128MB
max_connections = 50
PGCONF

echo "[+] Restarting PostgreSQL with custom config..."
systemctl restart postgresql

for i in {1..30}; do
  if pg_isready -q; then
    echo "[+] PostgreSQL is ready."
    break
  fi
  echo "  ...waiting after config restart ($i/30)"
  sleep 1
done

if ! pg_isready -q; then
  echo "ERROR: PostgreSQL failed to restart after applying config"
  journalctl -u postgresql -n 50
  exit 1
fi

################################
# Mount Data Disk Directly to PostgreSQL
#################################
echo "[+] Checking data disk..."

DATA_DISK=$(lsblk -dpno NAME,SIZE,TYPE | grep disk | grep -v "$(df / | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//')" | awk '{print $1}' | tail -1)

PG_DIR="/var/lib/postgresql/$${POSTGRES_VERSION}/main"

if [ -z "$DATA_DISK" ]; then
    echo "WARNING: No data disk found. Using OS disk for PostgreSQL data."
else
    echo "[+] Data disk found: $DATA_DISK"

    # Format only if brand new
    if ! blkid "$DATA_DISK" > /dev/null 2>&1; then
        echo "[+] Formatting data disk..."
        mkfs -t ext4 "$DATA_DISK"
    fi

    # Stop PostgreSQL before touching its home
    systemctl stop postgresql

    # If the data is still sitting on the OS disk, move it aside temporarily
    if [ -d "$PG_DIR" ] && [ -z "$(findmnt -n -o FSTYPE "$PG_DIR" 2>/dev/null)" ]; then
        echo "[+] Backing up original data..."
        mv "$PG_DIR" "$PG_DIR.backup"
        mkdir -p "$PG_DIR"
    fi

    # Mount the data disk directly into PostgreSQL's expected path
    if ! findmnt -n -o FSTYPE "$PG_DIR" > /dev/null 2>&1; then
        echo "[+] Mounting data disk to $PG_DIR..."
        mount "$DATA_DISK" "$PG_DIR"

        if ! grep -q "$DATA_DISK.*$PG_DIR" /etc/fstab; then
            echo "$DATA_DISK $PG_DIR ext4 defaults,nofail 0 2" >> /etc/fstab
        fi
    fi

    # If the mounted disk is empty, copy the original data into it
    if [ -d "$PG_DIR.backup" ] && [ -z "$(ls -A "$PG_DIR" 2>/dev/null)" ]; then
        echo "[+] Copying PostgreSQL data onto data disk..."
        cp -a "$PG_DIR.backup"/. "$PG_DIR/"
        rm -rf "$PG_DIR.backup"
    fi

    # Fix ownership
    chown -R postgres:postgres "$PG_DIR"
    chmod 700 "$PG_DIR"

    # Start and verify
    echo "[+] Starting PostgreSQL..."
    systemctl start postgresql

    for i in {1..30}; do
        if pg_isready -q; then
            echo "[+] PostgreSQL is ready."
            break
        fi
        echo "  ...waiting ($i/30)"
        sleep 1
    done

    if ! pg_isready -q; then
        echo "ERROR: PostgreSQL failed to start"
        journalctl -u postgresql@$${POSTGRES_VERSION}-main -n 50
        exit 1
    fi
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

#################################
# Wait for DB before migrations
#################################
echo "[+] Verifying PostgreSQL is reachable before migrations..."
for i in {1..30}; do
  if pg_isready -q -h localhost -p 5432; then
    echo "[+] PostgreSQL is accepting TCP connections."
    break
  fi
  echo "  ...waiting for TCP ($i/30)"
  sleep 1
done

if ! pg_isready -q -h localhost -p 5432; then
  echo "ERROR: PostgreSQL is not accepting TCP connections on localhost:5432"
  journalctl -u postgresql -n 50
  exit 1
fi

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