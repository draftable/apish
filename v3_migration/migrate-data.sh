#!/bin/bash
set -euo pipefail

# Non-disruptive data copy script
# Copies data from old running instance to new instance
# Both instances can run side-by-side during this process
#
# Usage: ./migrade-data.sh [OLD_COMPOSE_FILE] [NEW_COMPOSE_FILE]
#   OLD_COMPOSE_FILE: Path to old docker-compose file (default: docker-compose-old.yml)
#   NEW_COMPOSE_FILE: Path to new docker-compose file (default: docker-compose.yml)

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Parse arguments
OLD_COMPOSE_FILE="${1:-docker-compose-old.yml}"
NEW_COMPOSE_FILE="${2:-docker-compose.yml}"
TEMP_EXPORT_DIR="./temp-migration-data"

log() {
    # shellcheck disable=SC2312
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

log_success() {
    # shellcheck disable=SC2312
    echo -e "${GREEN}[$(date +'%H:%M:%S')] ✓${NC} $1"
}

log_warning() {
    # shellcheck disable=SC2312
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠${NC} $1"
}

log_error() {
    # shellcheck disable=SC2312
    echo -e "${RED}[$(date +'%H:%M:%S')] ✗${NC} $1"
}

echo ""
echo "=========================================="
echo "  Data Copy: Old → New Instance"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Old compose: $OLD_COMPOSE_FILE"
echo "  New compose: $NEW_COMPOSE_FILE"
echo ""

# Check prerequisites
log "Checking prerequisites..."

if [[ ! -f "$OLD_COMPOSE_FILE" ]]; then
    log_error "Old compose file not found: $OLD_COMPOSE_FILE"
    exit 1
fi

if [[ ! -f "$NEW_COMPOSE_FILE" ]]; then
    log_error "New compose file not found: $NEW_COMPOSE_FILE"
    exit 1
fi

log_success "Compose files found"

# Auto-detect volumes from compose files
log "Detecting volumes from compose files..."

# Get old app volume - look for volumes mounted to /srv/draftable
# First get the volume key, then extract the actual volume name
if ! OLD_VOLUME_KEY=$(docker compose -f "$OLD_COMPOSE_FILE" config --volumes | head -1); then
    log_error "Failed to read volumes from $OLD_COMPOSE_FILE. See error output above."
    exit 1
fi
if [[ -z "$OLD_VOLUME_KEY" ]]; then
    log_error "Could not detect old app volume from $OLD_COMPOSE_FILE"
    exit 1
fi

# Extract the actual volume name (which may have a 'name:' field)
OLD_APP_VOLUME=$(docker compose -f "$OLD_COMPOSE_FILE" config | grep -A 2 "^  $OLD_VOLUME_KEY:" | grep "name:" | awk '{print $2}')
if [[ -z "$OLD_APP_VOLUME" ]]; then
    log_error "Could not detect old app volume from $OLD_COMPOSE_FILE"
    exit 1
fi

# Get new app volume - look for the app data volume
# First try to find app_data volume key
if ! NEW_VOLUME_KEY=$(docker compose -f "$NEW_COMPOSE_FILE" config --volumes | grep -i "app" | head -1); then
    log_error "Failed to read volumes from $NEW_COMPOSE_FILE. See error output above."
    exit 1
fi
if [[ -z "$NEW_VOLUME_KEY" ]]; then
    log_error "Could not detect new app volume from $NEW_COMPOSE_FILE"
    exit 1
fi

# Extract the actual volume name (which may have a 'name:' field)
NEW_APP_VOLUME=$(docker compose -f "$NEW_COMPOSE_FILE" config | grep -A 2 "^  $NEW_VOLUME_KEY:" | grep "name:" | awk '{print $2}')
if [[ -z "$NEW_APP_VOLUME" ]]; then
    log_error "Could not detect new app volume from $NEW_COMPOSE_FILE"
    exit 1
fi

# Verify old volume exists
if ! docker volume inspect "$OLD_APP_VOLUME" &> /dev/null; then
    log_error "Old volume not found: $OLD_APP_VOLUME"
    log "Available volumes:"
    docker volume ls
    exit 1
fi
log_success "Old app volume: $OLD_APP_VOLUME"

# Verify new volume exists
if ! docker volume inspect "$NEW_APP_VOLUME" &> /dev/null; then
    log_error "New volume not found: $NEW_APP_VOLUME"
    log "Available volumes:"
    docker volume ls
    exit 1
fi
log_success "New app volume: $NEW_APP_VOLUME"

echo ""
echo "This script will:"
echo "  1. Export PostgreSQL data from OLD instance"
echo "  2. Import data into NEW instance (volume: $NEW_APP_VOLUME)"
echo "  3. Copy application files from OLD volume ($OLD_APP_VOLUME)"
echo "  4. Reinitialize the API to apply latest schema changes and activate imported license"

echo ""
echo "Both instances will continue running."
echo ""

# Create temp directory
mkdir -p "$TEMP_EXPORT_DIR"
log_success "Created temp directory: $TEMP_EXPORT_DIR"

# ============================================
# STEP 1: Export PostgreSQL from old instance
# ============================================
echo ""
echo "=========================================="
echo "Step 1: Export PostgreSQL Data"
echo "=========================================="

log "Detecting old instance containers..."

# Get all service names from old compose file
OLD_SERVICES=$(docker compose -f "$OLD_COMPOSE_FILE" config --services)
# shellcheck disable=SC2312
log "Services in old compose: $(echo "$OLD_SERVICES" | tr '\n' ' ')"

# Find the main application container (first service)
OLD_SERVICE=$(echo "$OLD_SERVICES" | head -1)
log "Using service: $OLD_SERVICE"

if ! OLD_CONTAINER=$(docker compose -f "$OLD_COMPOSE_FILE" ps -q "$OLD_SERVICE"); then
    log_error "Failed to get container ID for service: $OLD_SERVICE. See error output above."
    exit 1
fi

if [[ -z "$OLD_CONTAINER" ]]; then
    log_error "Existing API instance not detected, are you sure it's running on this machine?"
    exit 1
fi

log_success "Old container ID: $OLD_CONTAINER (service: $OLD_SERVICE)"

# Try to export PostgreSQL database
log "Attempting to export 'draftable' database..."

# Try pg_dump for draftable database
if docker exec "$OLD_CONTAINER" sh -c "command -v pg_dump" &> /dev/null; then
    log "Using pg_dump to export 'draftable' database..."
    if ! docker exec -u draftable "$OLD_CONTAINER" pg_dump -d draftable --create --clean > "$TEMP_EXPORT_DIR/draftable.sql"; then
        log_error "pg_dump failed. See error output above."
        exit 1
    fi
    log_success "Exported 'draftable' database to: $TEMP_EXPORT_DIR/draftable.sql"
else
    log_error "pg_dump command not found in container"
    exit 1
fi

# ============================================
# STEP 2: Import to new instance
# ============================================
echo ""
echo "=========================================="
echo "Step 2: Import to New Instance"
echo "=========================================="

# Extract database configuration from docker-compose
log "Extracting database configuration from compose file..."
NEW_DB_NAME=$(docker compose -f "$NEW_COMPOSE_FILE" config | grep -A 10 "^  pgsql:" | grep "POSTGRES_DB:" | awk '{print $2}' | head -1)
NEW_DB_USER=$(docker compose -f "$NEW_COMPOSE_FILE" config | grep -A 10 "^  pgsql:" | grep "POSTGRES_USER:" | awk '{print $2}' | head -1)
NEW_DB_PASS=$(docker compose -f "$NEW_COMPOSE_FILE" config | grep -A 10 "^  pgsql:" | grep "POSTGRES_PASSWORD:" | awk '{print $2}' | head -1)

# Fallback to defaults if not found
NEW_DB_NAME=${NEW_DB_NAME:-draftable}
NEW_DB_USER=${NEW_DB_USER:-postgres}
NEW_DB_PASS=${NEW_DB_PASS:-password}

# Check if new DB is running
if ! DB_STATUS=$(docker compose -f "$NEW_COMPOSE_FILE" ps pgsql 2>&1); then
    log_error "Failed to check PostgreSQL service status. See error output above."
    echo "$DB_STATUS"
    exit 1
fi

if ! echo "$DB_STATUS" | grep -q "Up"; then
    log "Starting new PostgreSQL service..."
    if ! docker compose -f "$NEW_COMPOSE_FILE" up -d pgsql; then
        log_error "Failed to start PostgreSQL service. See error output above."
        exit 1
    fi
fi

# Wait for PostgreSQL to be ready
log "Waiting for new PostgreSQL to be ready..."
for i in {1..30}; do
    if docker compose -f "$NEW_COMPOSE_FILE" exec -T pgsql pg_isready -U "$NEW_DB_USER" &> /dev/null; then
        log_success "New PostgreSQL is running"
        break
    fi
    if [[ "$i" -eq 30 ]]; then
        log_error "PostgreSQL did not become ready in time"
        exit 1
    fi
    sleep 2
done

# Import database
if [[ -f "$TEMP_EXPORT_DIR/draftable.sql" ]]; then
    log "Preparing database for import..."

    # Terminate all active connections to the target database (if it exists)
    # This ensures DROP DATABASE will succeed
    log "Terminating any active connections to '$NEW_DB_NAME'..."
    PGPASSWORD="$NEW_DB_PASS" docker compose -f "$NEW_COMPOSE_FILE" exec -T pgsql psql -U "$NEW_DB_USER" -d postgres <<-EOSQL > /dev/null 2>&1 || true
	SELECT pg_terminate_backend(pg_stat_activity.pid)
	FROM pg_stat_activity
	WHERE pg_stat_activity.datname = '$NEW_DB_NAME'
	  AND pid <> pg_backend_pid();
EOSQL

    log "Importing '$NEW_DB_NAME' database..."
    if ! PGPASSWORD="$NEW_DB_PASS" docker compose -f "$NEW_COMPOSE_FILE" exec -T pgsql psql -U "$NEW_DB_USER" -d postgres < "$TEMP_EXPORT_DIR/draftable.sql" > "$TEMP_EXPORT_DIR/migration.sql.log" 2>&1; then
        log_error "Failed to import database. See error output above."
        exit 1
    fi

    # Check for errors in the migration log (ignore expected errors)
    log "Checking migration log for errors..."

    # Define error patterns to ignore (add more as needed)
    IGNORED_ERRORS=(
        'role "draftable" does not exist'
    )

    # Get all errors from the log
    IMPORT_ERRORS=$(grep -i "ERROR:" "$TEMP_EXPORT_DIR/migration.sql.log" || true)

    # Filter out ignored errors
    for pattern in "${IGNORED_ERRORS[@]}"; do
        IMPORT_ERRORS=$(echo "$IMPORT_ERRORS" | grep -v "$pattern" || true)
    done

    if [[ -n "$IMPORT_ERRORS" ]]; then
        log_error "Errors found in database import:"
        echo ""
        echo "$IMPORT_ERRORS"
        echo ""
        log_error "Database import completed with errors. Check $TEMP_EXPORT_DIR/migration.sql.log for details."
        exit 1
    fi

    log_success "Database '$NEW_DB_NAME' imported successfully"

else
    log_error "No PostgreSQL export found at: $TEMP_EXPORT_DIR/draftable.sql"
    log_error "Cannot continue without database export"
    exit 1
fi

# ============================================
# STEP 3: Copy application files
# ============================================
echo ""
echo "=========================================="
echo "Step 3: Copy Application Files"
echo "=========================================="

log "Copying files from volume: $OLD_APP_VOLUME"

# Create new volume if it doesn't exist
if ! docker volume inspect "$NEW_APP_VOLUME" &> /dev/null; then
    log "Creating new volume: $NEW_APP_VOLUME"
    docker volume create "$NEW_APP_VOLUME"
fi

# Copy data from old volume to new volume (only config, data, and fonts folders)
# and set ownership to 1001:1001 (draftable user)
log "Copying data: $OLD_APP_VOLUME → $NEW_APP_VOLUME"
if ! docker run --rm \
    -v "$OLD_APP_VOLUME:/src:ro" \
    -v "$NEW_APP_VOLUME:/dst" \
    alpine \
    sh -c 'mkdir -p /dst/config /dst/data /dst/fonts && \
           if [ -d /src/config ]; then cp -a /src/config/. /dst/config/ 2>&1 | grep -v "can'\''t preserve" || true; fi && \
           if [ -d /src/data ]; then cp -a /src/data/. /dst/data/ 2>&1 | grep -v "can'\''t preserve" || true; fi && \
           if [ -d /src/fonts ]; then cp -a /src/fonts/. /dst/fonts/ 2>&1 | grep -v "can'\''t preserve" || true; fi && \
           chown -R 1001:1001 /dst/config /dst/data /dst/fonts'; then
    log_error "Failed to copy application files. See error output above."
    exit 1
fi

log_success "Application files copied successfully"

# Reinitialize application to apply latest schema changes and activate imported license
log "Updating database schema and activating imported license..."
docker compose -f "$NEW_COMPOSE_FILE" up web_init --exit-code-from web_init 2>&1 | grep -v "Aborting on container exit"
if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
    log_error "Failed to initialize web service. See error output above."
    exit 1
fi
log_success "Database update completed"

# Restart compare service to activate imported license
log "Restarting compare service..."
if ! docker compose -f "$NEW_COMPOSE_FILE" restart compare; then
    log_error "Failed to restart compare service. See error output above."
    exit 1
fi
log_success "Compare service restarted"


# ============================================
# STEP 4: Verification
# ============================================
echo ""
echo "=========================================="
echo "Step 4: Verification"
echo "=========================================="

log "Verifying new instance..."

# Check volumes
if docker volume inspect "$NEW_APP_VOLUME" &> /dev/null; then
    log_success "New app volume exists"
else
    log_error "New app volume missing"
fi

# Check database
if PGPASSWORD="$NEW_DB_PASS" docker compose -f "$NEW_COMPOSE_FILE" exec -T pgsql psql -U "$NEW_DB_USER" -l > /dev/null 2>&1; then
    log_success "New database is accessible"
else
    log_error "Could not connect to new database"
    exit 1
fi

echo ""
echo "=========================================="
log_success "Data Copy Complete!"
echo "=========================================="
