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

        # mkfs.ext4 always creates lost+found, which was tricking the
        # "is this empty" check below into thinking data was already there.
        rmdir "$PG_DIR/lost+found" 2>/dev/null || true
    fi

    # A real cluster always has a PG_VERSION file — that's a much more
    # reliable signal than "directory is empty" (lost+found breaks that).
    if [ -d "$PG_DIR.backup" ] && [ ! -f "$PG_DIR/PG_VERSION" ]; then
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