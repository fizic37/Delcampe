# Deployment Workflow Guide

**Last Updated**: 2025-11-05
**Environment**: Hetzner Cloud + Docker + Cloudflare Tunnel

## Overview

This guide documents the complete workflow for developing features locally and deploying them to production on Hetzner Cloud.

---

## Table of Contents

1. [Local Development Workflow](#local-development-workflow)
2. [Testing Before Deployment](#testing-before-deployment)
3. [Git Workflow](#git-workflow)
4. [Docker Deployment to Hetzner](#docker-deployment-to-hetzner)
5. [Cloudflare Tunnel Setup](#cloudflare-tunnel-setup)
6. [Troubleshooting Common Issues](#troubleshooting-common-issues)

---

## Local Development Workflow

### 1. Start Development

```r
# In RStudio, load the project
setwd("C:/Users/mariu/Documents/R_Projects/Delcampe")

# Load all functions for testing
devtools::load_all()

# Run the app locally
golem::run_dev()
```

**Local Environment**:
- Database: `inst/app/data/tracking.sqlite`
- Credentials: `.Renviron` (local file, not committed)
- Port: Random port assigned by RStudio
- Access: `http://localhost:<port>`

### 2. Make Changes

Follow the project structure:
```
R/
├── mod_*.R           # Shiny modules
├── *_helpers.R       # Helper functions
├── *_database.R      # Database functions
└── app_*.R           # App configuration
```

**Key Principles**:
- Always use Serena tools for code search/edit
- Keep modules under 400 lines
- Write tests alongside code
- Use `get_db_path()` for database path abstraction

### 3. Test Locally

```r
# Run critical tests (MUST pass before commit)
source("dev/run_critical_tests.R")

# Run discovery tests (optional, failures are OK)
source("dev/run_discovery_tests.R")
```

**Test Requirements**:
- All critical tests must pass (100%)
- Use test helpers: `with_test_db()`, `with_mocked_ai()`
- Test both success and error paths

---

## Testing Before Deployment

### Critical Test Suite

**Location**: `dev/run_critical_tests.R`

**Run before EVERY commit**:
```r
source("dev/run_critical_tests.R")
```

**Expected Result**: ✅ All tests pass (currently ~170 tests)

**Files tested**:
- `tests/testthat/test-ebay_helpers.R`
- `tests/testthat/test-utils_helpers.R`
- `tests/testthat/test-mod_delcampe_export.R`
- `tests/testthat/test-mod_tracking_viewer.R`

### Discovery Test Suite

**Location**: `dev/run_discovery_tests.R`

**Run during development** (failures are learning opportunities):
```r
source("dev/run_discovery_tests.R")
```

**Expected Result**: ⚠️ Some failures expected (currently ~100 tests)

**Files tested**:
- `tests/testthat/test-ai_api_helpers.R`
- `tests/testthat/test-tracking_database.R`
- Module templates

---

## Git Workflow

### 1. Check Status

```bash
git status
```

**Important**: Never commit sensitive credentials!
- `.env.production` - server only
- `.Renviron` - local only
- Backup files in `R/` directory

### 2. Stage Changes

```bash
# Stage specific files
git add R/mod_new_feature.R
git add tests/testthat/test-mod_new_feature.R

# Or stage all (be careful!)
git add .
```

### 3. Commit with Meaningful Message

```bash
git commit -m "feat: Add new postal card upload validation

- Validate image dimensions before upload
- Show user-friendly error messages
- Add tests for validation logic"
```

**Commit Message Format**:
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation only
- `test:` - Adding tests
- `refactor:` - Code restructuring

### 4. Push to GitHub

**From Windows Git Bash or GitHub Desktop**:
```bash
git push origin main
```

**Note**: From WSL, git push requires credential configuration. Use Windows tools instead.

---

## Docker Deployment to Hetzner

### Architecture Overview

```
Local Development (Windows)
    ↓ git push
GitHub Repository
    ↓ git pull (on Hetzner)
Hetzner Server (Ubuntu)
    ↓ docker build
Docker Container (Shiny Server + R + Python)
    ↓ exposed on port 3838
Cloudflare Tunnel
    ↓ HTTPS
User's Browser
```

### Step 1: Connect to Hetzner

```bash
# From WSL or Windows PowerShell
ssh root@37.27.80.87
```

**Server Details**:
- IP: `37.27.80.87`
- OS: Ubuntu
- Volume: `/mnt/HC_Volume_103879961` (10GB, mounted to `/data` in container)

### Step 2: Pull Latest Code

```bash
cd /root/Delcampe
git pull origin main
```

**Troubleshooting**: If git pull fails:
```bash
# Check current branch
git status

# Stash local changes if any
git stash

# Pull again
git pull origin main
```

### Step 3: Rebuild Docker Image

```bash
# Build the image (takes 10-15 minutes)
docker build -t delcampe-app:latest .
```

**What happens during build**:
1. Base image: `rocker/shiny:4.3.3` (R + Shiny Server)
2. System dependencies: OpenCV, SQLite, curl
3. R package installation from `DESCRIPTION`
4. Python virtual environment setup
5. Application code copy
6. Startup script creation

**Build output**:
- Image size: ~2-3 GB
- Duration: 10-15 minutes (faster on subsequent builds due to caching)

### Step 4: Restart Container

```bash
# Stop and remove old container
docker-compose down

# Start new container
docker-compose up -d
```

**What happens**:
1. Startup script creates `.Renviron` from environment variables
2. Shiny Server starts on port 3838
3. Volume mounted: `/mnt/HC_Volume_103879961` → `/data`
4. Database initialized: `/data/tracking.sqlite`

### Step 5: Verify Deployment

```bash
# Check container status
docker-compose ps

# Should show:
# NAME              STATUS        PORTS
# delcampe-app      Up (healthy)  0.0.0.0:3838->3838/tcp

# Check logs
docker-compose logs -f

# Should see:
# Creating .Renviron from environment variables...
# .Renviron created successfully
# Listening on http://127.0.0.1:xxxxx
```

### Step 6: Check Environment Variables

```bash
# Verify credentials loaded
docker exec delcampe-app printenv | grep EBAY

# Should show:
# EBAY_ENVIRONMENT=production
# EBAY_PROD_CLIENT_ID=...
# EBAY_PROD_CLIENT_SECRET=...
# EBAY_REDIRECT_URI=https://...trycloudflare.com
```

### Step 7: Check Application Logs

```bash
# List log files
docker exec delcampe-app ls -lt /var/log/shiny-server/

# Read latest log
docker exec delcampe-app cat /var/log/shiny-server/delcampe-shiny-XXXXXXX.log
```

**Healthy startup logs**:
```
Using Docker volume database: /data/tracking.sqlite
✅ Database initialized with AI extraction & eBay tracking
Listening on http://127.0.0.1:40723
✅ User authenticated: master1@delcampe.com
```

---

## Cloudflare Tunnel Setup

### Why Cloudflare Tunnel?

**Problem**: eBay OAuth requires HTTPS redirect URIs in production

**Solution**: Cloudflare Tunnel provides free HTTPS without buying a domain

### Quick Tunnel (Temporary URL)

**Use Case**: Testing, development, temporary access

**Limitations**:
- URL changes on every restart
- No uptime guarantee
- Must keep SSH session open

**Setup**:

1. **SSH into Hetzner** (separate session):
```bash
ssh root@37.27.80.87
```

2. **Start Quick Tunnel**:
```bash
cloudflared tunnel --url http://localhost:3838
```

3. **Copy the HTTPS URL** from output:
```
Your quick Tunnel has been created! Visit it at:
https://random-words-here.trycloudflare.com
```

4. **Keep this terminal open** - closing stops the tunnel

### Using `screen` to Keep Tunnel Running

**Use Case**: Close SSH without stopping tunnel

```bash
# Install screen
apt install screen -y

# Start screen session
screen -S cloudflared

# Run tunnel
cloudflared tunnel --url http://localhost:3838

# Detach: Press Ctrl+A, then D
# You can now close SSH

# Reconnect later:
ssh root@37.27.80.87
screen -r cloudflared
```

### Update Configuration After Tunnel Start

1. **Get tunnel URL** from cloudflared output

2. **Update .env.production**:
```bash
cd /root/Delcampe
nano .env.production

# Update this line:
EBAY_REDIRECT_URI=https://your-tunnel-url.trycloudflare.com
```

3. **Restart container**:
```bash
docker-compose down
docker-compose up -d
```

4. **Verify**:
```bash
docker exec delcampe-app printenv | grep EBAY_REDIRECT_URI
# Should show the tunnel URL
```

5. **Update eBay Developer Portal**:
   - Go to: https://developer.ebay.com/my/keys
   - Find RuName: `TITA_MARIUS-TITAMARI-Delcam-njpondg`
   - Set **Your auth accepted URL**: `https://your-tunnel-url.trycloudflare.com`
   - Set **Your auth declined URL**: `https://your-tunnel-url.trycloudflare.com`
   - **Remove trailing slashes** if present
   - Save

### Named Tunnel (Permanent URL)

**Use Case**: Production deployment with stable URL

**Requires**: Adding a domain to Cloudflare (free)

**Benefits**:
- URL stays the same
- Auto-restarts on server reboot
- Better reliability

**Setup**: See `docs/CLOUDFLARE_TUNNEL_PERMANENT.md` (TODO)

---

## Troubleshooting Common Issues

### Issue 1: "unauthorized_client" Error

**Symptom**: Can't connect eBay account, error in browser

**Causes**:
1. Redirect URI mismatch between app and eBay portal
2. Environment variables not loaded in R session
3. Using HTTP instead of HTTPS

**Solution**:
```bash
# 1. Check environment variables
docker exec delcampe-app printenv | grep EBAY_REDIRECT_URI

# 2. Check it matches eBay portal exactly (no trailing slash)
# 3. Restart container after .env changes
docker-compose down && docker-compose up -d

# 4. Verify .Renviron created
docker exec delcampe-app cat /srv/shiny-server/delcampe/.Renviron
```

### Issue 2: "Table users has no column named user_id"

**Symptom**: Can't start session after login

**Cause**: Database schema mismatch (old vs new authentication system)

**Solution**: Already fixed in codebase
- Old schema: `user_id TEXT PRIMARY KEY`
- New schema: `id INTEGER PRIMARY KEY`
- JOIN clauses updated to use `u.id`

**If persists on Hetzner**:
```bash
# Delete old database (will recreate with new schema)
ssh root@37.27.80.87
rm /mnt/HC_Volume_103879961/tracking.sqlite

# Restart container
docker-compose down && docker-compose up -d
```

### Issue 3: Environment Variables Empty

**Symptom**: `docker exec delcampe-app printenv | grep EBAY` shows empty values

**Cause**: docker-compose.yml has `environment:` section with `${VAR}` substitution

**Solution**: Remove `environment:` section from docker-compose.yml
```yaml
# WRONG (tries to substitute before loading env_file):
environment:
  - EBAY_ENVIRONMENT=${EBAY_ENVIRONMENT}

# CORRECT (only use env_file):
env_file:
  - .env.production
```

### Issue 4: "unable to open database file"

**Symptom**: App crashes on startup

**Cause**: Volume permissions - shiny user can't write to `/data`

**Solution**:
```bash
# On Hetzner server
chown -R 999:999 /mnt/HC_Volume_103879961

# 999 is the UID of 'shiny' user in container
```

### Issue 5: Infinite Recursion on Startup

**Symptom**: App crashes with "evaluation nested too deeply"

**Cause**: `get_db_path()` called in function default parameters

**Solution**: Already fixed in codebase
```r
# WRONG:
initialize_tracking_db <- function(db_path = get_db_path()) {

# CORRECT:
initialize_tracking_db <- function(db_path = NULL) {
  if (is.null(db_path)) db_path <- get_db_path()
```

### Issue 6: Cloudflare Tunnel Error 1033

**Symptom**: "Cloudflare Tunnel error" when visiting HTTPS URL

**Causes**:
1. cloudflared not running on Hetzner server
2. Docker container not running
3. cloudflared pointing to wrong port

**Solution**:
```bash
# Check cloudflared is running on Hetzner (not local machine!)
ssh root@37.27.80.87
screen -r cloudflared

# If not running, start it:
screen -S cloudflared
cloudflared tunnel --url http://localhost:3838

# Check Docker is running:
docker-compose ps
```

### Issue 7: Git Push Fails from WSL

**Symptom**: "could not read Username for 'https://github.com'"

**Cause**: WSL doesn't have GitHub credentials configured

**Solution**: Push from Windows instead
```bash
# Option 1: Use Windows Git Bash
# Option 2: Use GitHub Desktop
# Option 3: Configure WSL git to use Windows credentials
git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"
```

---

## Quick Reference Commands

### Local Development
```bash
# Load and run app
devtools::load_all()
golem::run_dev()

# Run tests
source("dev/run_critical_tests.R")
```

### Git Commands
```bash
git status
git add <files>
git commit -m "type: message"
git push origin main
```

### Hetzner Deployment
```bash
# Connect
ssh root@37.27.80.87

# Deploy
cd /root/Delcampe
git pull origin main
docker build -t delcampe-app:latest .
docker-compose down
docker-compose up -d

# Verify
docker-compose ps
docker-compose logs -f
docker exec delcampe-app printenv | grep EBAY
```

### Cloudflare Tunnel
```bash
# Start quick tunnel
cloudflared tunnel --url http://localhost:3838

# With screen (detachable)
screen -S cloudflared
cloudflared tunnel --url http://localhost:3838
# Ctrl+A, D to detach

# Reattach
screen -r cloudflared
```

### Docker Debugging
```bash
# Container status
docker-compose ps

# Follow logs
docker-compose logs -f

# Enter container shell
docker exec -it delcampe-app /bin/bash

# Check environment
docker exec delcampe-app printenv | grep EBAY

# Check .Renviron
docker exec delcampe-app cat /srv/shiny-server/delcampe/.Renviron

# Check app logs
docker exec delcampe-app cat /var/log/shiny-server/delcampe-shiny-*.log
```

---

## Environment Variable Management

### Local Development (.Renviron)

**Location**: `/mnt/c/Users/mariu/Documents/R_Projects/Delcampe/.Renviron`

**Content** (local credentials only, not committed):
```bash
# AI API Keys (Optional)
ANTHROPIC_API_KEY=sk-ant-api03-...
OPENAI_API_KEY=sk-proj-...

# eBay Sandbox (for local testing)
EBAY_ENVIRONMENT=sandbox
EBAY_SANDBOX_CLIENT_ID=...
EBAY_SANDBOX_CLIENT_SECRET=...
EBAY_SANDBOX_CERT_ID=...
EBAY_SANDBOX_DEV_ID=...
EBAY_REDIRECT_URI=http://localhost:3838
```

### Production (.env.production)

**Location**: `/root/Delcampe/.env.production` (on Hetzner only)

**Content** (production credentials, not committed):
```bash
EBAY_ENVIRONMENT=production
EBAY_PROD_CLIENT_ID=TITAMARI-Delcampe-PRD-...
EBAY_PROD_CLIENT_SECRET=PRD-...
EBAY_PROD_CERT_ID=PRD-...
EBAY_PROD_DEV_ID=...
EBAY_REDIRECT_URI=https://your-tunnel.trycloudflare.com
```

### How Environment Variables Flow

```
1. docker-compose.yml loads .env.production
   ↓
2. Container environment has EBAY_* vars
   ↓
3. Startup script reads env vars
   ↓
4. Creates .Renviron in app directory
   ↓
5. R session reads .Renviron via Sys.getenv()
   ↓
6. EbayAPIConfig$initialize() loads credentials
```

**Critical**: Without `.Renviron`, R can't see environment variables set in docker-compose!

---

## Next Steps

- [ ] Set up permanent Cloudflare Tunnel with domain
- [ ] Configure automatic deployments with GitHub Actions
- [ ] Set up monitoring and alerting
- [ ] Configure automated backups
- [ ] Add SSL certificate for custom domain

## Related Documentation

- [Database Operations Guide](DATABASE_OPERATIONS.md)
- [Testing Guide](../dev/TESTING_GUIDE.md)
- [Architecture Overview](architecture/overview.md)
- [PRP: Docker Deployment](../PRPs/PRP_DOCKER_DEPLOYMENT_HETZNER.md)
