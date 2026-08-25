#!/bin/bash
set -e

#############################
# Config
#################################
APP_DIR="/opt/secure-login-demo"
DOCKER_DATA="/mnt/docker-data"

#################################
# System update + Docker
#################################
echo "[+] Updating system..."
apt-get update && apt-get upgrade -y

echo "[+] Installing Docker..."
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable docker


usermod -aG docker ${vm_username}

#################################
# Azure CLI
#################################
echo "[+] Installing Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

#################################
# VM Identity Login
#################################
echo "[+] Authenticating with VM managed identity..."
LOGGED_IN=0
i=1
while [ "$i" -le 10 ]; do
  if az login --identity >/tmp/az-login.log 2>&1; then
    LOGGED_IN=1
    break
  fi
  echo "  ...retry $i/10"
  i=$((i + 1))
  sleep 10
done
if [ "$LOGGED_IN" -ne 1 ]; then
  echo "ERROR: could not authenticate with managed identity. Aborting."
  cat /tmp/az-login.log
  exit 1
fi
#################################
# Data Disk -> Docker
#################################
echo "[+] Setting up data disk for Docker..."

# Find the OS disk device
OS_DISK=$(findmnt -n -o SOURCE / | sed 's/\[.*\]//;s/[0-9]*$//')
# Find the data disk (any disk that is not the OS disk)
DATA_DISK=$(lsblk -dpno NAME,TYPE | awk '$2=="disk"{print $1}' | grep -v "^$OS_DISK$" | head -n1)

if [ -z "$DATA_DISK" ]; then
  echo "[!] WARNING: No data disk found. Using OS disk for docker data."
  mkdir -p "$DOCKER_DATA"
else
  echo "[+] Data disk found: $DATA_DISK"
  mkdir -p "$DOCKER_DATA"
  
  # FIX: Only format if the disk has no existing filesystem
  if blkid "$DATA_DISK" > /dev/null 2>&1; then
    echo "[+] Filesystem already exists on $DATA_DISK. Skipping format."
  else
    echo "[+] No filesystem found. Formatting $DATA_DISK..."
    mkfs.ext4 -F "$DATA_DISK"
  fi
  
  mount "$DATA_DISK" "$DOCKER_DATA"
  echo "$DATA_DISK $DOCKER_DATA ext4 defaults,nofail 0 2" >> /etc/fstab
fi
#################################
# Fetch app files from GitHub
#################################
echo "[+] Fetching deploy files (branch: ${app_branch})..."
mkdir -p "$APP_DIR/frontend/nginx"
cd "$APP_DIR"

REPO_PATH=$(echo "${app_repo_url}" | sed -E 's#https?://github\.com/##; s#\.git$##; s#/$##')
RAW_BASE="https://raw.githubusercontent.com/$${REPO_PATH}/${app_branch}"

curl -fsSL "$${RAW_BASE}/docker-compose.prod.yml" -o "$APP_DIR/docker-compose.prod.yml"


#################################
# Get DB password from Key Vault
#################################
echo "[+] Fetching db-password from Key Vault ${key_vault_name}..."
DB_PASSWORD=$(az keyvault secret show --name db-password --vault-name "${key_vault_name}" --query value -o tsv)

#################################
# Write env files
#################################
echo "[+] Writing env files..."

cat > "$APP_DIR/backend.env" <<ENVFILE
AZURE_KEY_VAULT_URL=${key_vault_url}
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_POOL_MAX=${db_pool_max}
DB_TIMEOUT=${db_timeout}
DB_IDLE_TIMEOUT=${db_idle_timeout}
DB_STATEMENT_TIMEOUT=${db_statement_timeout}
FRONTEND_URL=${frontend_url}
API_URL=${api_url}
GITHUB_CLIENT_ID=${github_client_id}
GITHUB_CALLBACK_URL=${github_callback_url}
GOOGLE_CLIENT_ID=${google_client_id}
GOOGLE_CALLBACK_URL=${google_callback_url}
SMTP_HOST=${smtp_host}
SMTP_PORT=${smtp_port}
SMTP_USER=${smtp_user}
SMTP_FROM=${smtp_from}
RUN_MIGRATIONS=true
ENVFILE
chmod 600 "$APP_DIR/backend.env"

cat > "$APP_DIR/db.env" <<ENVFILE
POSTGRES_USER=${db_user}
POSTGRES_PASSWORD=$${DB_PASSWORD}
POSTGRES_DB=${db_name}
ENVFILE
chmod 600 "$APP_DIR/db.env"

unset DB_PASSWORD

cat > "$APP_DIR/.env" <<ENVFILE
DOCKERHUB_USERNAME=${dockerhub_username}
DOMAIN_NAME=${domain_name}
IMAGE_TAG=$${image_tag:-latest}
ENVFILE
chmod 600 "$APP_DIR/.env"

chown -R ${vm_username}:${vm_username} "$APP_DIR"
#################################
# Pull & start INFRA first 
#################################
echo "[+] Pulling infrastructure images..."
COMPOSE="docker compose -f docker-compose.prod.yml"
$COMPOSE pull db redis certbot

echo "[+] Starting infrastructure (db, redis, certbot)..."
$COMPOSE up -d db redis certbot

sleep 15

#################################
# Try to pull & start APP images (may fail if not pushed yet)
#################################
echo "[+] Pulling app images..."
$COMPOSE pull backend frontend 2>/dev/null || echo "[!] App images not on Docker Hub yet — CI/CD will deploy them later."

echo "[+] Starting app (backend, frontend)..."
$COMPOSE up -d backend frontend 2>/dev/null || echo "[!] App not started — waiting for first CI/CD deploy."

#################################
# SSL Certificate Bootstrap
#################################
echo "[+] Setting up SSL certificate..."

COMPOSE="docker compose -f $APP_DIR/docker-compose.prod.yml"
DOMAIN_NAME="${domain_name}"

#  Do we already have a real Let's Encrypt cert?
echo "[+] Checking for existing certificate..."
if $COMPOSE run --rm --entrypoint sh certbot -c "
  [ -f /etc/letsencrypt/live/$${DOMAIN_NAME}/fullchain.pem ] && \
  openssl x509 -in /etc/letsencrypt/live/$${DOMAIN_NAME}/fullchain.pem -noout -issuer 2>/dev/null | grep -qi 'letsencrypt'
" 2>/dev/null; then
    echo "[+] Real Let's Encrypt certificate already exists on data disk. Skipping bootstrap."
    $COMPOSE up -d --remove-orphans
    $COMPOSE exec frontend nginx -s reload 2>/dev/null || true
else
    echo "[+] No real certificate found. Running bootstrap..."

  
    wait_for_nginx() {
        local max_attempts=30
        local wait_sec=2
        echo "[+] Waiting for nginx to serve on port 80..."
        for i in $(seq 1 $max_attempts); do
            if curl -sf --max-time 3 http://localhost > /dev/null 2>&1; then
                echo "[+] Nginx is responding on port 80 (attempt $i/$max_attempts)."
                return 0
            fi
            echo "    ...not ready yet ($i/$max_attempts), retrying in $${wait_sec}s"
            sleep $wait_sec
        done
        echo "[!] Nginx failed to start after $((max_attempts * wait_sec))s."
        return 1
    }

    # --- Step 1: Create placeholder certificate so nginx can boot ---
    echo "[+] Creating placeholder certificate..."
    $COMPOSE run --rm --entrypoint sh certbot-init -c "
      mkdir -p /etc/letsencrypt/live/$${DOMAIN_NAME}
      if [ ! -f /etc/letsencrypt/live/$${DOMAIN_NAME}/fullchain.pem ]; then
        openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
          -keyout /etc/letsencrypt/live/$${DOMAIN_NAME}/privkey.pem \
          -out /etc/letsencrypt/live/$${DOMAIN_NAME}/fullchain.pem \
          -subj '/CN=$${DOMAIN_NAME}'
        echo '[+] Placeholder cert created.'
      else
        echo '[+] Certificate already exists.'
      fi
    " || {
        echo "[!] Warning: certbot-init container failed, but continuing..."
    }

    # --- Step 2: Start the full stack ---
    echo "[+] Starting application stack..."
    $COMPOSE up -d --remove-orphans

    # --- Step 3: Wait for nginx to be actually serving ---
    if ! wait_for_nginx; then
        echo "[!] CRITICAL: Nginx is not running. Cannot proceed with Let's Encrypt."
        echo "[!] Frontend logs:"
        $COMPOSE logs --tail 50 frontend
        echo "[!] Continuing with placeholder certificate. Site will work but with browser warnings."
    else
        # --- Step 4: Obtain real certificate via webroot ---
        echo "[+] Requesting real certificate from Let's Encrypt..."

        if $COMPOSE run --rm --entrypoint sh certbot -c "
          certbot certonly --webroot -w /var/www/certbot \
            -d $${DOMAIN_NAME} \
            --agree-tos --non-interactive \
            --register-unsafely-without-email \
            --cert-name $${DOMAIN_NAME}
        "; then
            echo "[+] Real certificate obtained successfully!"

            # --- Step 5: Reload nginx to pick up the real cert ---
            echo "[+] Reloading nginx with real certificate..."
            $COMPOSE exec frontend nginx -s reload 2>/dev/null || {
                echo "[!] Reload failed, restarting frontend..."
                $COMPOSE restart frontend
                sleep 3
            }

            # Verify HTTPS is responding
            if curl -sf --max-time 5 -k https://localhost > /dev/null 2>&1; then
                echo "[+] HTTPS is responding with the new certificate."
            else
                echo "[!] HTTPS check failed, but nginx should be running."
            fi
        else
            echo "[!] Let's Encrypt failed. Keeping placeholder certificate."
            echo "[!] Common causes:"
            echo "    - Port 80 not open in Azure NSG"
            echo "    - Domain $${DOMAIN_NAME} not pointing to this VM's public IP"
            echo "    - Let's Encrypt rate limit hit"
            echo "[!] The site will work with a browser security warning."
        fi
    fi
fi

echo "[+] SSL bootstrap complete."
$COMPOSE ps
#################################
# Cleanup
#################################
az logout 2>/dev/null || true
shred -u /var/lib/cloud/instance/user-data.txt 2>/dev/null || true
shred -u /var/log/cloud-init.log 2>/dev/null || true
shred -u /var/log/cloud-init-output.log 2>/dev/null || true

#################################
# Done
#################################
echo "================================"
echo " Cloud-Init Complete"
echo "================================"
echo "Domain: https://${domain_name}"
cd "$APP_DIR"
$COMPOSE ps 2>/dev/null || echo "No containers yet — waiting for CI/CD."
