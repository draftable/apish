# Migration Guide: V2 to V3 Draftable API Self-Hosted

This guide walks you through migrating database and application files from a V2 Draftable API Self-Hosted instance to V3. Both instances run side-by-side during migration to ensure zero downtime.

## What Gets Migrated

1. **PostgreSQL database** - Complete `draftable` database from V2 container → V3 PostgreSQL service
2. **Application files** - All data in `/srv/draftable` volume → V3 app volume
3. **License** - Existing license key is automatically activated in V3

## Prerequisites

### System Requirements
- Docker Engine 20.10+ (for Compose V2 support)
- Docker Compose V2 (command: `docker compose` not `docker-compose`)
- Bash shell
  - **Linux/macOS**: Native bash support
  - **Windows**: Use WSL2 (recommended), Git Bash, or Cygwin
- Sufficient disk space (2x your current data size recommended)

### Verify Your Setup

Run these commands to confirm your environment meets the requirements:

```bash
# Check Docker version
docker --version
# Expected: Docker version 20.10.0 or higher

# Check Compose version
docker compose version
# Expected: Docker Compose version v2.x.x or higher

# Check available disk space
df -h
# Ensure you have at least 2x your current V2 data size
```

### Download V3 Configuration

Download the new V3 `docker-compose.yml` file from Draftable before proceeding.

### Environment Configuration

Ensure your `.env` file is configured for V3. Create or update it with these variables:

```bash
# Required variables
DJANGO_SECRET_KEY=<set_django_secret>
DB_PASS=<set_db_password>
AMQP_PASSWORD=<set_rabbit_password>

# Optional variables
# SERVER_DNS=<your_domain_or_ip>
# DB_USER=postgres
# AMQP_USER=draftable
# TLS_CERT=<tls_cert_value>
# TLS_KEY=<tls_key_value>
# TLS_CA_CHAIN=<tls_ca_chain_value>
# COMPARE_WORKERS_COUNT=<number>
```

## Quick Start

For those familiar with the process, here's the condensed version:

```bash
# Step 1: Start V3 instance on custom ports (runs alongside V2)
HTTP_PORT=3080 HTTPS_PORT=3443 docker compose -f path/to/new/docker-compose.yml up -d

# Verify V3 is running at http://localhost:3080

# Step 2: Run migration script
bash migrate-data.sh path/to/old/docker-compose.yml path/to/new/docker-compose.yml

# Step 3: Test V3 instance
# Visit http://localhost:3080 and verify all data is present

# Step 4: Switch over to V3
docker compose -f path/to/old/docker-compose.yml stop
docker compose -f path/to/new/docker-compose.yml stop
docker compose -f path/to/new/docker-compose.yml up -d

# V3 now running on default ports (https://localhost)
```

## Detailed Usage

### Step 1: Start V3 Instance

Start the V3 instance on custom ports to verify it works before migrating data. This allows both V2 and V3 to run simultaneously:

```bash
# Start V3 on custom ports (port 3080 for HTTP, 3443 for HTTPS)
HTTP_PORT=3080 HTTPS_PORT=3443 docker compose -f path/to/new/docker-compose.yml up -d

# Check logs to ensure services started successfully
docker compose -f path/to/new/docker-compose.yml logs -f

# Verify V3 is accessible
curl http://localhost:3080
```

Visit http://localhost:3080 in your browser to confirm the V3 instance is running.

If you're running the instance on a remote host, you'll need to set up SSH tunneling to access the web interface on your local machine, e.g.:

```
ssh -L 3080:localhost:3080 -N -f -i /temptemp  user@host
```


### Step 2: Run Migration Script

**⚠️ IMPORTANT:** Treat your V2 instance as **read-only** during the migration process. Any new data created in V2 after the migration script starts (e.g., new comparisons, user changes) will **NOT** be transferred to V3. To avoid data loss, ensure all users stop making changes to the V2 instance before beginning the migration.

Navigate to the migration directory and execute the migration script:

```bash
# Run migration with paths to both compose files
bash migrate-data.sh path/to/old/docker-compose.yml path/to/new/docker-compose.yml
```

**What the script does:**

1. **Export V2 database** - Uses `pg_dump` to export the `draftable` database from V2
2. **Import to V3** - Imports the database dump into the V3 PostgreSQL service
3. **Apply migrations** - Runs Django migrations to update schema to V3 format
4. **Copy application files** - Transfers all files from `/srv/draftable` volume to V3
5. **Activate license** - Automatically activates your existing license key in V3
6. **Verify migration** - Performs basic checks to ensure data integrity


### Step 3: Test V3 Instance

Thoroughly test the V3 instance to ensure all data migrated correctly. Both V2 and V3 are running simultaneously at this point:

- **V2 instance**: Running on default ports (http://localhost or https://localhost)
- **V3 instance**: Running on http://localhost:3080

**Testing checklist:**

- [ ] Log in with existing credentials
- [ ] Verify all comparisons are present
- [ ] Check that application files are accessible
- [ ] Test creating a new comparison
- [ ] Verify license is activated
- [ ] Review any custom configurations

### Step 4: Switch Over to V3

Once you've confirmed V3 works correctly, switch over to make it the primary instance:

```bash
# Stop both instances
docker compose -f path/to/old/docker-compose.yml stop
docker compose -f path/to/new/docker-compose.yml stop

# Start V3 on default ports
docker compose -f path/to/new/docker-compose.yml up -d
```

V3 is now running on the default ports. Access it at https://localhost (or your configured SERVER_DNS).

### Step 5: Cleanup (Optional)

After confirming the migration was successful and V3 is stable:

```bash
# Remove temporary migration files (if any were created)
rm -rf temp-migration-data/

# Stop and remove V2 containers
docker compose -f path/to/old/docker-compose.yml down

# Optional: Remove V2 volumes (WARNING: This is irreversible!)
# List volumes first to identify V2 volumes
docker volume ls

# Remove specific V2 volumes
docker volume rm <v2_volume_name>
```

**⚠️ Warning:** Only remove V2 volumes after you're completely satisfied with the V3 migration. This action cannot be undone.
