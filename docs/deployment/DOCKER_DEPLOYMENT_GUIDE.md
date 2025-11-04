# Delcampe Docker Deployment Guide

Complete guide for deploying the Delcampe postal card processor to Hetzner Cloud with Docker and persistent volume storage.

---

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Architecture Overview](#architecture-overview)
3. [Prerequisites](#prerequisites)
4. [Initial Setup](#initial-setup)
5. [Deployment Process](#deployment-process)
6. [Database Management](#database-management)
7. [Monitoring and Maintenance](#monitoring-and-maintenance)
8. [Troubleshooting](#troubleshooting)
9. [Security Checklist](#security-checklist)
10. [Performance Tuning](#performance-tuning)
11. [Next Steps](#next-steps)

---

## Quick Reference

### Essential Commands

```bash
# On Hetzner server:
cd /root/Delcampe

# Deploy
./dev/docker_deploy.sh

# Check status
docker-compose ps
docker-compose logs -f

# Backup database
./dev/docker_backup.sh

# Restart
docker-compose restart

# Stop
docker-compose down

# Update code and redeploy
git pull
./dev/docker_deploy.sh
```

### Key Files

- `Dockerfile` - Container image definition
- `docker-compose.yml` - Container orchestration
- `.env.production` - Production credentials (server only, not in git)
- `dev/docker_build.sh` - Build script
- `dev/docker_deploy.sh` - Deployment script
- `dev/docker_backup.sh` - Database backup script

---

## Architecture Overview

### System Components

```
┌─────────────────────────────────────────────────┐
│ Hetzner Cloud VPS (cx22, Falkenstein)           │
│                                                   │
│  ┌──────────────────────────────────────────┐   │
│  │ Docker Container (delcampe-app)          │   │
│  │                                           │   │
│  │  - Shiny Server (port 3838)             │   │
│  │  - R 4.3.3 + Python 3.12                │   │
│  │  - Reticulate + OpenCV                   │   │
│  │                                           │   │
│  │  Volume Mount: /data → /mnt/delcampe-data│   │
│  └──────────────────────────────────────────┘   │
│                                                   │
│  ┌──────────────────────────────────────────┐   │
│  │ Hetzner Cloud Volume (10GB, ext4)        │   │
│  │                                           │   │
│  │  /mnt/delcampe-data/                     │   │
│  │    └── tracking.sqlite (persistent)      │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

### Database Path Strategy

The application uses `get_db_path()` to automatically detect the environment:

- **Docker**: `/data/tracking.sqlite` → mounted to `/mnt/delcampe-data/`
- **Local Dev**: `inst/app/data/tracking.sqlite`

This allows the same codebase to work in both environments without changes.

### Credential Strategy

**Three-Tier Credential System:**

1. **OAuth App Credentials** (Environment Variables)
   - Location: `.env.production` on server
   - Not in git (security)
   - Used for eBay OAuth app registration
   - Allows users to authenticate their eBay accounts

2. **User-Managed API Keys** (App Data Files)
   - Claude/OpenAI API keys
   - Managed per-user through app UI
   - Stored in app data files (not environment variables)

3. **OAuth Tokens** (Database)
   - eBay user access tokens
   - Generated via OAuth flow
   - Stored per-user in database
   - Automatically refreshed

**What Goes Where:**
- ✅ `.env.production`: eBay OAuth app credentials (EBAY_PROD_*)
- ✅ Database: OAuth tokens, user data
- ✅ App data files: User API keys (Claude, OpenAI)
- ❌ `.Renviron`: Only sandbox credentials (local dev)

---

## Prerequisites

### On Local Machine

- Git
- Hetzner Cloud CLI (`hcloud`)
- SSH client
- SSH key pair registered with Hetzner

### On Hetzner Server

- Ubuntu Server with Docker pre-installed (docker-ce image)
- Cloud volume attached (10GB minimum)
- Port 3838 open in firewall

---

## Initial Setup

### 1. Create Hetzner Cloud Volume

```bash
# Login to Hetzner
hcloud context create delcampe-prod
# Paste API token from https://console.hetzner.cloud/

# Create volume
hcloud volume create \
  --name delcampe-data \
  --size 10 \
  --location fsn1 \
  --format ext4
```

### 2. Create Hetzner VPS

```bash
# Create server with Docker
hcloud server create \
  --name delcampe-prod \
  --type cx22 \
  --image docker-ce \
  --location fsn1 \
  --ssh-key YOUR_SSH_KEY_NAME \
  --volume delcampe-data

# Get server IP
SERVER_IP=$(hcloud server ip delcampe-prod)
echo "Server IP: $SERVER_IP"
```

### 3. Mount Volume on Server

```bash
# SSH to server
ssh root@$SERVER_IP

# Find volume device
lsblk
# Look for 10G disk

# Format volume (ONLY FIRST TIME!)
mkfs.ext4 /dev/disk/by-id/scsi-0HC_Volume_*

# Create mount point
mkdir -p /mnt/delcampe-data

# Mount volume
mount /dev/disk/by-id/scsi-0HC_Volume_* /mnt/delcampe-data

# Auto-mount on reboot
echo "/dev/disk/by-id/scsi-0HC_Volume_* /mnt/delcampe-data ext4 defaults 0 0" >> /etc/fstab

# Verify mount
df -h | grep delcampe-data
```

### 4. Clone Repository and Setup Credentials

```bash
# Install git
apt update && apt install -y git

# Clone repository
cd /root
git clone https://github.com/YOURUSERNAME/Delcampe.git
cd Delcampe

# Create production environment file
nano .env.production
```

**Content for .env.production:**

```bash
# eBay Production OAuth App Credentials
EBAY_PROD_CLIENT_ID=TITAMARI-Delcampe-PRD-2ead09bb4-ebc86ad4
EBAY_PROD_CLIENT_SECRET=PRD-ead09bb48777-72d3-4499-9b7e-dd18
EBAY_PROD_DEV_ID=f31d6100-687c-483f-b762-a0d486e12a68

EBAY_REDIRECT_URI=TITA_MARIUS-TITAMARI-Delcam-njpondg
EBAY_ENVIRONMENT=production
```

**Secure the file:**

```bash
chmod 600 .env.production
chown root:root .env.production
```

---

## Deployment Process

### First-Time Deployment

```bash
# SSH to server
ssh root@$SERVER_IP
cd /root/Delcampe

# Build Docker image (10-15 minutes)
docker build -t delcampe-app:latest .

# Create SQLite directory on volume
mkdir -p /mnt/delcampe-data/sqlite
chmod 755 /mnt/delcampe-data/sqlite

# Start with docker-compose
docker-compose up -d

# Wait for startup (60 seconds)
sleep 60

# Check status
docker-compose ps
docker-compose logs --tail=50

# Verify app accessible
curl http://localhost:3838
```

### Update Deployment

```bash
# SSH to server
ssh root@$SERVER_IP
cd /root/Delcampe

# Pull latest code
git pull

# Rebuild and restart
./dev/docker_deploy.sh
```

### Using Deployment Script

The `dev/docker_deploy.sh` script automates:
1. Pull latest code from git
2. Build Docker image
3. Stop old container
4. Start new container
5. Wait for health check
6. Show logs and status

```bash
./dev/docker_deploy.sh
```

---

## Database Management

### Backup

**Manual Backup:**

```bash
./dev/docker_backup.sh
```

**Automated Backup (Cron):**

```bash
# Add to crontab
crontab -e

# Backup daily at 2 AM
0 2 * * * /root/Delcampe/dev/docker_backup.sh >> /var/log/delcampe-backup.log 2>&1
```

### Restore

```bash
# Stop container
docker-compose down

# Extract backup
gunzip -c /root/delcampe-backups/tracking_20250104_020000.sqlite.gz > /tmp/tracking.sqlite

# Replace database
cp /tmp/tracking.sqlite /mnt/delcampe-data/sqlite/tracking.sqlite
rm /tmp/tracking.sqlite

# Start container
docker-compose up -d
```

### Database Integrity Check

```bash
sqlite3 /mnt/delcampe-data/sqlite/tracking.sqlite "PRAGMA integrity_check;"
# Expected: ok
```

### Database Access

```bash
# From server
sqlite3 /mnt/delcampe-data/sqlite/tracking.sqlite

# From container
docker exec -it delcampe-app sqlite3 /data/tracking.sqlite
```

---

## Monitoring and Maintenance

### Health Check

```bash
# Container health
docker inspect delcampe-app | grep -A 5 "Health"

# Health check endpoint
curl http://localhost:3838

# From outside
curl http://YOUR_SERVER_IP:3838
```

### Logs

```bash
# Live logs
docker-compose logs -f

# Last 100 lines
docker-compose logs --tail=100

# Errors only
docker-compose logs | grep -i error

# Save logs to file
docker-compose logs > /tmp/delcampe-logs.txt
```

### Resource Usage

```bash
# Container stats
docker stats delcampe-app

# Disk usage
df -h /mnt/delcampe-data
du -sh /mnt/delcampe-data/sqlite/

# Memory usage
docker exec delcampe-app free -h
```

### Updates

**Application Updates:**

```bash
git pull
./dev/docker_deploy.sh
```

**System Updates:**

```bash
apt update && apt upgrade -y
# Reboot if kernel updated
reboot
```

**Docker Updates:**

```bash
apt update && apt upgrade docker-ce docker-ce-cli containerd.io
systemctl restart docker
docker-compose up -d
```

---

## Troubleshooting

### Container Won't Start

**Check logs:**

```bash
docker-compose logs
```

**Common issues:**

1. **Missing .env.production**
   ```bash
   ls -la .env.production
   # Create if missing
   ```

2. **Volume not mounted**
   ```bash
   df -h | grep delcampe-data
   # Remount if needed
   ```

3. **Port already in use**
   ```bash
   netstat -tulpn | grep 3838
   # Kill conflicting process
   ```

### App Not Accessible

**Check container running:**

```bash
docker-compose ps
# Expected: Up (healthy)
```

**Check firewall:**

```bash
ufw status
ufw allow 3838/tcp
```

**Check port binding:**

```bash
docker port delcampe-app
# Expected: 3838/tcp -> 0.0.0.0:3838
```

### Database Errors

**Check database file exists:**

```bash
ls -lh /mnt/delcampe-data/sqlite/tracking.sqlite
```

**Check permissions:**

```bash
chmod 644 /mnt/delcampe-data/sqlite/tracking.sqlite
chown 999:999 /mnt/delcampe-data/sqlite/tracking.sqlite
```

**Check integrity:**

```bash
sqlite3 /mnt/delcampe-data/sqlite/tracking.sqlite "PRAGMA integrity_check;"
```

### Python Integration Errors

**Check Python installed:**

```bash
docker exec delcampe-app python3 --version
```

**Check OpenCV:**

```bash
docker exec delcampe-app python3 -c "import cv2; print(cv2.__version__)"
```

**Check virtual environment:**

```bash
docker exec delcampe-app ls -la /srv/shiny-server/delcampe/venv_proj/
```

### Performance Issues

**Check resource usage:**

```bash
docker stats delcampe-app
```

**Check slow queries:**

```bash
sqlite3 /mnt/delcampe-data/sqlite/tracking.sqlite
PRAGMA analysis_limit=400;
PRAGMA optimize;
```

**Restart container:**

```bash
docker-compose restart
```

---

## Security Checklist

### Production Secrets

- [x] `.env.production` has 600 permissions (root only)
- [x] `.env.production` NOT in git
- [x] `.Renviron` has NO production credentials
- [x] `.gitignore` includes `.env.production`, `.env.local`, `.Renviron.local`

### Server Security

```bash
# Update system
apt update && apt upgrade -y

# Setup firewall
ufw allow 22/tcp
ufw allow 3838/tcp
ufw enable

# Disable root SSH (after creating user)
# Edit /etc/ssh/sshd_config
# PermitRootLogin no
# systemctl restart sshd
```

### Credential Rotation

**Rotate eBay OAuth credentials:**

1. Generate new credentials at https://developer.ebay.com/my/keys
2. Update `.env.production` on server
3. Restart container: `docker-compose restart`
4. Users will need to re-authenticate their eBay accounts

**Rotate user API keys:**

Users manage their own Claude/OpenAI keys through the app UI. No server action needed.

---

## Performance Tuning

### Docker Resources

Edit `docker-compose.yml` to add resource limits:

```yaml
services:
  delcampe-app:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          cpus: '1'
          memory: 2G
```

### SQLite Optimization

```bash
sqlite3 /mnt/delcampe-data/sqlite/tracking.sqlite
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA cache_size = -64000;
PRAGMA temp_store = memory;
ANALYZE;
```

### Shiny Server Configuration

Edit Dockerfile to customize:

```bash
# Increase worker processes
RUN echo "app_init_timeout 300;" >> /etc/shiny-server/shiny-server.conf
RUN echo "app_idle_timeout 300;" >> /etc/shiny-server/shiny-server.conf
```

---

## Next Steps

### Phase 2: SSL & Domain

1. Setup Nginx reverse proxy
2. Configure Let's Encrypt SSL certificate
3. Map custom domain (delcampe.yourdomain.com)
4. Update eBay OAuth redirect URIs

**Nginx Configuration Example:**

```nginx
server {
    listen 80;
    server_name delcampe.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name delcampe.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/delcampe.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/delcampe.yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://localhost:3838;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Phase 3: Monitoring

- Setup uptime monitoring (UptimeRobot, Pingdom)
- Configure log aggregation (Loki, ELK)
- Add Grafana dashboards
- Setup alerts (email, Slack)

### Phase 4: CI/CD

- GitHub Actions workflow for automated builds
- Automated testing on pull requests
- Automated deployment on main branch merge
- Blue-green deployment strategy

---

## Support

### Documentation

- Main docs: `docs/README.md`
- Architecture: `docs/architecture/overview.md`
- Serena memory: `.serena/memories/docker_deployment_hetzner_complete_*.md`

### Logs Location

- Application logs: `docker-compose logs`
- Shiny Server logs: `/var/log/shiny-server/` (in container)
- System logs: `/var/log/syslog`
- Backup logs: `/var/log/delcampe-backup.log`

### Common Commands

```bash
# Check all services
docker-compose ps

# Restart service
docker-compose restart

# View configuration
docker-compose config

# Remove everything (CAREFUL!)
docker-compose down -v

# Rebuild from scratch
docker-compose build --no-cache
docker-compose up -d
```

---

## Appendix: File Structure

```
Delcampe/
├── Dockerfile                    # Container definition
├── docker-compose.yml            # Container orchestration
├── .dockerignore                 # Build context exclusions
├── .env.production.template      # Environment template (in git)
├── .env.production              # Actual credentials (NOT in git)
├── dev/
│   ├── docker_build.sh          # Build script
│   ├── docker_deploy.sh         # Deployment script
│   └── docker_backup.sh         # Backup script
├── docs/
│   └── deployment/
│       └── DOCKER_DEPLOYMENT_GUIDE.md  # This file
├── R/
│   ├── tracking_database.R      # Uses get_db_path()
│   ├── auth_system.R            # Uses get_db_path()
│   └── ...                      # All use get_db_path()
└── inst/app/data/               # Local dev database location
    └── tracking.sqlite          # (not in Docker)
```

**On Hetzner Server:**

```
/root/Delcampe/                  # Application code
/mnt/delcampe-data/              # Persistent volume mount
  └── sqlite/
      └── tracking.sqlite        # Production database
/root/delcampe-backups/          # Database backups
  ├── tracking_20250104_020000.sqlite.gz
  ├── tracking_20250105_020000.sqlite.gz
  └── ...
```

---

**Last Updated**: 2025-11-04
**Version**: 1.0
**Status**: Production Ready
