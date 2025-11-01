# Hetzner + Docker: Best of Both Worlds Solution

**Date:** 2025-10-30
**Your Valid Concern:** "Without Docker, I might have R version and package conflicts"
**Answer:** You're 100% right. Here's the complete solution.

---

## Executive Summary

**Your concern is valid and professional.** Here are your three options:

| Approach | Reproducibility | SQLite Support | Complexity | Time | Best For |
|----------|----------------|----------------|------------|------|----------|
| **Option 1: renv** ⭐⭐⭐ | Excellent | Native | Low | 30 min | **RECOMMENDED** |
| **Option 2: Docker + Volumes** ⭐⭐ | Perfect | Native | Medium | 2 hours | Docker fans |
| **Option 3: Native Install** ⭐ | Good enough | Native | Very Low | 1 hour | Quick & dirty |

**TL;DR:** Use **renv** (Option 1). It gives you Docker-level reproducibility without Docker complexity, and SQLite works perfectly.

---

## Your Current Environment

From your system:
- **R Version:** 4.3.3 (2024-02-29 "Angel Food Cake")
- **Python Version:** 3.12.3
- **Platform:** WSL2 (Ubuntu on Windows)

**Key packages:**
```r
# From DESCRIPTION:
Imports: base64enc, bslib, config, curl, DBI, digest, DT, golem,
         httr2, jsonlite, later, magick, reticulate, RSQLite,
         shiny, shinyjs, xml2
```

---

## Option 1: renv (Project-Local Packages) ⭐⭐⭐ RECOMMENDED

### What Is renv?

Think of it as "Docker for R packages":
- Creates project-specific library (isolated from system R)
- Records exact package versions in `renv.lock` file
- Restores identical environment on any machine
- **No Docker needed**, **SQLite works natively**

### Why This Solves Your Problem

**Your concern:**
```
Development (Windows/WSL):      Production (Hetzner):
├─ R 4.3.3                      ├─ R 4.4.2 (newer) ⚠️
├─ shiny 1.8.0                  ├─ shiny 1.9.1 (breaking changes?) ⚠️
├─ golem 0.4.1                  ├─ golem 0.5.0 (different API?) ⚠️
└─ magick 2.8.0                 └─ magick 2.8.3 (works differently?) ⚠️
```

**With renv:**
```
Development:                     Production:
├─ R 4.3.3                      ├─ R 4.3.3 (locked)
├─ renv.lock file ────────────→ ├─ renv.lock file
│   shiny = 1.8.0                  shiny = 1.8.0 ✅ (exact match)
│   golem = 0.4.1                  golem = 0.4.1 ✅ (exact match)
│   magick = 2.8.0                 magick = 2.8.0 ✅ (exact match)
└─ SQLite works                 └─ SQLite works (same filesystem)
```

---

### Implementation (30 minutes)

#### Step 1: Set Up renv Locally (10 minutes)

```r
# In your R console (in project directory)
install.packages("renv")

# Initialize renv for your project
renv::init()

# This creates:
# - renv/ directory (project library)
# - renv.lock file (exact package versions)
# - .Rprofile (loads renv automatically)

# Snapshot current state (records all package versions)
renv::snapshot()

# Test that it works
renv::restore()  # Should say "nothing to restore"
```

**What just happened:**
- Created `renv.lock` file with ALL package versions
- Isolated your project from system R packages
- Your app now has reproducible dependencies

**Example `renv.lock` snippet:**
```json
{
  "R": {
    "Version": "4.3.3",
    "Repositories": [
      {
        "Name": "CRAN",
        "URL": "https://cloud.r-project.org"
      }
    ]
  },
  "Packages": {
    "shiny": {
      "Package": "shiny",
      "Version": "1.8.0",
      "Source": "Repository",
      "Repository": "CRAN"
    },
    "golem": {
      "Package": "golem",
      "Version": "0.4.1",
      "Source": "Repository",
      "Repository": "CRAN"
    }
    // ... all your packages with exact versions
  }
}
```

#### Step 2: Update .gitignore (2 minutes)

```bash
# Add to .gitignore:
renv/library/     # Don't commit installed packages
renv/staging/     # Temporary download directory

# KEEP in git:
renv.lock         # This is your dependency snapshot
.Rprofile         # Loads renv automatically
renv/activate.R   # renv activation script
```

#### Step 3: Commit renv Files (3 minutes)

```bash
git add renv.lock .Rprofile renv/activate.R renv/settings.json
git commit -m "Add renv for reproducible deployments"
git push
```

#### Step 4: Deploy to Hetzner with renv (15 minutes)

**On Hetzner server:**

```bash
# SSH into server
ssh root@your-server-ip

# Install specific R version (match your dev environment)
apt update
apt install -y software-properties-common dirmngr wget

# Add CRAN repository for R 4.3.3
wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marullus.asc | \
  tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"

apt update

# Install R 4.3.x (same major.minor as your dev)
apt install -y r-base=4.3.3-1.2404.0 r-base-dev=4.3.3-1.2404.0

# Hold R version (prevent automatic upgrades)
apt-mark hold r-base r-base-dev

# Verify R version
R --version  # Should show R version 4.3.3

# Install system dependencies
apt install -y \
  libcurl4-openssl-dev \
  libssl-dev \
  libxml2-dev \
  libmagick++-dev \
  libsqlite3-dev \
  python3 \
  python3-pip \
  python3-venv

# Clone your app
cd /srv/shiny-server
git clone https://github.com/yourusername/Delcampe.git delcampe
cd delcampe

# Install renv package (system-wide)
R -e "install.packages('renv', repos='https://cloud.r-project.org/')"

# Restore exact package versions from renv.lock
R -e "renv::restore()"

# This will:
# 1. Read renv.lock
# 2. Download exact versions specified
# 3. Install them in project-local library
# 4. Match your development environment EXACTLY

# Set up Python environment (same as dev)
python3 -m venv venv_proj
source venv_proj/bin/activate
pip install opencv-python==4.x.x numpy==1.x.x  # Use same versions as dev

# Install Shiny Server
wget https://download3.rstudio.org/ubuntu-18.04/x86_64/shiny-server-1.5.21.1012-amd64.deb
apt install -y ./shiny-server-1.5.21.1012-amd64.deb

# Set permissions
chown -R shiny:shiny /srv/shiny-server/delcampe

# Start Shiny Server
systemctl start shiny-server
```

**That's it!** Your production environment now exactly matches your development environment.

---

### Updating Your App (With renv)

**Scenario 1: Update app code (no new packages)**

```bash
# On Hetzner:
cd /srv/shiny-server/delcampe
git pull
systemctl restart shiny-server
```

**Scenario 2: Added new packages**

```r
# On your development machine:
# 1. Install new package
install.packages("newpackage")

# 2. Update renv.lock
renv::snapshot()

# 3. Commit and push
git add renv.lock
git commit -m "Add newpackage dependency"
git push
```

```bash
# On Hetzner:
cd /srv/shiny-server/delcampe
git pull

# Install new packages from updated renv.lock
R -e "renv::restore()"

systemctl restart shiny-server
```

**Scenario 3: Update R version**

```r
# Development:
# 1. Update R to new version (e.g., 4.4.0)
# 2. Update renv.lock
renv::snapshot()
```

```bash
# Production:
# 1. Update R on Hetzner
apt-mark unhold r-base r-base-dev
apt install r-base=4.4.0-1.2404.0
apt-mark hold r-base r-base-dev

# 2. Restore packages for new R version
cd /srv/shiny-server/delcampe
R -e "renv::restore()"
```

---

### Pros & Cons

**Pros:**
- ✅ **Perfect reproducibility** - Same as Docker
- ✅ **No Docker complexity** - Just R packages
- ✅ **SQLite works natively** - No volumes needed
- ✅ **Easy updates** - `renv::restore()`
- ✅ **Version control** - `renv.lock` in git
- ✅ **Fast deployment** - No Docker image builds
- ✅ **Small overhead** - Just package management
- ✅ **Works with Golem** - Designed for Golem projects

**Cons:**
- ⚠️ **Requires R version match** - Must install same R version on server
- ⚠️ **System dependencies** - Still need to install libcurl, libssl, etc.
- ⚠️ **Python separate** - Doesn't manage Python packages (use venv)

**When to use:**
- ✅ You want reproducibility without Docker
- ✅ You want SQLite to work natively
- ✅ You're comfortable matching R versions
- ✅ You prefer simplicity (this is 90% of cases)

---

## Option 2: Docker + Hetzner Volumes ⭐⭐

### What Is This?

Run your app in Docker container on Hetzner, but mount SQLite database from Hetzner Cloud Volume (persistent storage).

### Architecture

```
Hetzner VPS:
  ├─ Docker
  │   └─ Your app container (ephemeral)
  │       ├─ R 4.3.3 (locked)
  │       ├─ All packages (locked versions)
  │       └─ /data → (mounted from volume)
  │
  └─ Hetzner Cloud Volume (persistent)
      └─ tracking.sqlite ← Persists forever
```

---

### Implementation (2-3 hours)

#### Step 1: Create Dockerfile with renv (30 minutes)

**Create `Dockerfile` in your project root:**

```dockerfile
# Use specific R version to match development
FROM rocker/shiny:4.3.3

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libmagick++-dev \
    libsqlite3-dev \
    python3 \
    python3-pip \
    python3-venv \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
RUN mkdir -p /srv/shiny-server/delcampe
WORKDIR /srv/shiny-server/delcampe

# Copy renv files first (for Docker layer caching)
COPY renv.lock renv.lock
COPY .Rprofile .Rprofile
COPY renv/activate.R renv/activate.R
COPY renv/settings.json renv/settings.json

# Install renv
RUN R -e "install.packages('renv', repos='https://cloud.r-project.org/')"

# Restore R packages from renv.lock
RUN R -e "renv::restore()"

# Copy application code
COPY . .

# Set up Python environment
RUN python3 -m venv venv_proj && \
    . venv_proj/bin/activate && \
    pip install opencv-python numpy

# Create mount point for persistent data
RUN mkdir -p /data

# Expose Shiny port
EXPOSE 3838

# Run Shiny Server
CMD ["/usr/bin/shiny-server"]
```

**Create `.dockerignore`:**

```
.git
.gitignore
renv/library
renv/staging
inst/app/data/*.sqlite
inst/app/data/*.sqlite-*
test_images
tests
PRPs
docs
.serena
*.md
.Rproj.user
*.Rproj
```

#### Step 2: Update App to Use Mounted Volume (15 minutes)

**Modify `R/tracking_database.R`:**

```r
#' Get database path based on environment
get_db_path <- function() {
  # Check if running in Docker with mounted volume
  if (file.exists("/data")) {
    return("/data/tracking.sqlite")
  } else {
    # Local development
    return("inst/app/data/tracking.sqlite")
  }
}

#' Initialize the tracking database
initialize_tracking_db <- function(db_path = NULL) {
  if (is.null(db_path)) {
    db_path <- get_db_path()
  }

  tryCatch({
    dir.create(dirname(db_path), recursive = TRUE, showWarnings = FALSE)
    con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
    # ... rest of your initialization code
  }, error = function(e) {
    message("❌ Failed to initialize database: ", e$message)
    return(FALSE)
  })
}
```

**Update all database connections:**

```r
# BEFORE:
con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")

# AFTER:
con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
```

#### Step 3: Build and Test Locally (20 minutes)

```bash
# Build Docker image
docker build -t delcampe-app:latest .

# Test locally (without volume first)
docker run -p 3838:3838 \
  -e CLAUDE_API_KEY=your-key \
  -e OPENAI_API_KEY=your-key \
  delcampe-app:latest

# Test with local volume
docker run -p 3838:3838 \
  -v $(pwd)/test-data:/data \
  -e CLAUDE_API_KEY=your-key \
  delcampe-app:latest

# Access at http://localhost:3838
```

#### Step 4: Deploy to Hetzner with Volume (60 minutes)

**Create Hetzner server + volume:**

```bash
# Install Hetzner CLI (on your local machine)
brew install hcloud  # macOS
# or
curl -s https://raw.githubusercontent.com/hetznercloud/cli/master/scripts/install.sh | bash

# Login
hcloud context create delcampe-prod
# Enter your API token from https://console.hetzner.cloud/

# Create volume (10GB)
hcloud volume create \
  --name delcampe-data \
  --size 10 \
  --location fsn1

# Create server with Docker
hcloud server create \
  --name delcampe-prod \
  --type cx22 \
  --image docker-ce \
  --location fsn1 \
  --ssh-key your-ssh-key

# Attach volume to server
hcloud volume attach delcampe-data delcampe-prod
```

**SSH into server and set up volume:**

```bash
# SSH into server
ssh root@your-server-ip

# Format and mount volume (first time only)
mkfs.ext4 /dev/disk/by-id/scsi-0HC_Volume_*
mkdir -p /mnt/delcampe-data
mount /dev/disk/by-id/scsi-0HC_Volume_* /mnt/delcampe-data

# Auto-mount on reboot
echo "/dev/disk/by-id/scsi-0HC_Volume_* /mnt/delcampe-data ext4 defaults 0 0" >> /etc/fstab

# Create data directory
mkdir -p /mnt/delcampe-data/sqlite
chown -R 999:999 /mnt/delcampe-data  # Shiny user in container
```

**Deploy Docker container:**

```bash
# Pull or build image on server
# Option A: Push to Docker Hub and pull
docker pull yourusername/delcampe-app:latest

# Option B: Build on server
cd /root
git clone https://github.com/yourusername/Delcampe.git
cd Delcampe
docker build -t delcampe-app:latest .

# Run container with volume mounted
docker run -d \
  --name delcampe-app \
  --restart unless-stopped \
  -p 3838:3838 \
  -v /mnt/delcampe-data/sqlite:/data \
  -e CLAUDE_API_KEY="${CLAUDE_API_KEY}" \
  -e OPENAI_API_KEY="${OPENAI_API_KEY}" \
  -e EBAY_SANDBOX_CLIENT_ID="${EBAY_SANDBOX_CLIENT_ID}" \
  -e EBAY_SANDBOX_CLIENT_SECRET="${EBAY_SANDBOX_CLIENT_SECRET}" \
  delcampe-app:latest

# Check logs
docker logs -f delcampe-app

# Set up nginx reverse proxy (optional)
# ... same as Option 1
```

#### Step 5: Create docker-compose.yml (15 minutes)

**For easier management:**

```yaml
# docker-compose.yml
version: '3.8'

services:
  delcampe-app:
    image: delcampe-app:latest
    container_name: delcampe-app
    restart: unless-stopped
    ports:
      - "3838:3838"
    volumes:
      - /mnt/delcampe-data/sqlite:/data
    environment:
      - CLAUDE_API_KEY=${CLAUDE_API_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - EBAY_SANDBOX_CLIENT_ID=${EBAY_SANDBOX_CLIENT_ID}
      - EBAY_SANDBOX_CLIENT_SECRET=${EBAY_SANDBOX_CLIENT_SECRET}
      - EBAY_PROD_CLIENT_ID=${EBAY_PROD_CLIENT_ID}
      - EBAY_PROD_CLIENT_SECRET=${EBAY_PROD_CLIENT_SECRET}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3838"]
      interval: 30s
      timeout: 10s
      retries: 3
```

**Deploy:**

```bash
# Set environment variables
export CLAUDE_API_KEY=your-key
export OPENAI_API_KEY=your-key
# ... etc

# Start
docker-compose up -d

# View logs
docker-compose logs -f

# Restart
docker-compose restart

# Stop
docker-compose down
```

---

### Updating Your App (Docker + Volumes)

```bash
# 1. Update code locally, commit, push
git push

# 2. SSH to Hetzner
ssh root@your-server-ip

# 3. Rebuild image
cd /root/Delcampe
git pull
docker build -t delcampe-app:latest .

# 4. Restart container
docker-compose down
docker-compose up -d

# Database persists in /mnt/delcampe-data/sqlite !
```

---

### Pros & Cons

**Pros:**
- ✅ **Perfect reproducibility** - Containerized environment
- ✅ **SQLite persists** - Volume survives container restarts
- ✅ **True isolation** - Container can't affect host
- ✅ **Easy rollback** - Keep old Docker images
- ✅ **Portable** - Same Docker image runs anywhere
- ✅ **Professional** - Industry standard approach

**Cons:**
- ⚠️ **More complexity** - Docker + volumes + docker-compose
- ⚠️ **Longer builds** - Docker image rebuild time
- ⚠️ **Learning curve** - Need Docker knowledge
- ⚠️ **Volume setup** - Extra configuration step
- ⚠️ **More expensive** - Volume costs €1/month extra

**When to use:**
- ✅ You know Docker well
- ✅ You want industry-standard deployment
- ✅ You might scale to Kubernetes later
- ✅ You value complete isolation

---

## Option 3: Native Install (No Docker, No renv) ⭐

### What Is This?

Just install R + packages on Hetzner, deploy your app. Hope versions match.

### Quick Setup (1 hour)

```bash
# Install latest R
apt update
apt install -y r-base r-base-dev

# Install ALL packages
R -e "install.packages(c('shiny', 'golem', 'DBI', 'RSQLite', ...))"

# Deploy app
git clone ...
# Start Shiny Server
```

---

### Pros & Cons

**Pros:**
- ✅ **Fastest setup** - No renv, no Docker
- ✅ **Simplest** - Just install and run
- ✅ **SQLite works** - Native filesystem

**Cons:**
- ❌ **No reproducibility** - Versions may differ
- ❌ **Update risk** - `apt upgrade` might break app
- ❌ **No version control** - Can't track package versions
- ❌ **Debugging hell** - "Works on my machine" syndrome

**When to use:**
- ⚠️ You're prototyping
- ⚠️ You'll rebuild from scratch if it breaks
- ⚠️ You don't care about long-term maintenance

**Recommendation:** Don't use this for production.

---

## Comparison Matrix

| Feature | renv | Docker + Volumes | Native Install |
|---------|------|------------------|----------------|
| **Reproducibility** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| **Setup Time** | 30 min | 2-3 hours | 1 hour |
| **Complexity** | Low | Medium-High | Very Low |
| **SQLite Support** | ✅ Native | ✅ Volume | ✅ Native |
| **Update Process** | Easy | Medium | Easy but risky |
| **Monthly Cost** | $5 | $6 (volume) | $5 |
| **Version Control** | renv.lock | Dockerfile | None |
| **Industry Standard** | ✅ Yes (R) | ✅ Yes (general) | ❌ No |
| **Learning Curve** | Low | Medium | None |
| **Portability** | Medium | High | Low |
| **Debugging** | Easy | Medium | Hard |

---

## My Strong Recommendation

### Use **renv** (Option 1)

**Why:**

1. **Solves your version concern** - Just as good as Docker
2. **Keeps SQLite simple** - No volumes, no mounting
3. **Low complexity** - Just R package management
4. **Fast deployment** - 30 minutes setup
5. **Easy updates** - `renv::restore()`
6. **Industry standard** - Used by Posit, RStudio
7. **Golem-friendly** - Designed for Golem projects

**When to use Docker instead:**

- You plan to deploy to Kubernetes
- You have complex system dependencies beyond R
- You want to run multiple isolated instances
- You're already a Docker expert

For 2-5 users with SQLite, **renv is perfect**.

---

## Implementation Checklist

### This Weekend: Set Up renv

**Saturday morning (30 minutes):**

```r
# In your project:
install.packages("renv")
renv::init()
renv::snapshot()

# Test it works
renv::restore()

# Commit
git add renv.lock .Rprofile renv/
git commit -m "Add renv for reproducibility"
git push
```

**Saturday afternoon (2 hours):**

Follow "Hetzner + renv deployment" from Option 1.

**Sunday:**

✅ App is live with reproducible environment
✅ SQLite works perfectly
✅ No Docker complexity

---

## Future-Proofing

### If You Need Docker Later

**Easy transition:**

1. You already have renv.lock
2. Create Dockerfile (use renv.lock)
3. Deploy Docker version
4. Zero data loss (SQLite file stays same)

**The renv.lock file works in both scenarios!**

---

## Conclusion

**Your concern about versioning is valid and professional.**

**Three solutions:**

1. ⭐⭐⭐ **renv** - Docker-level reproducibility, no Docker complexity, SQLite native
2. ⭐⭐ **Docker + Volumes** - Industry standard, more complex, SQLite on volume
3. ⭐ **Native** - Fast but risky, not recommended for production

**For your use case (2-5 users, SQLite, Golem app):**

👉 **Use renv on Hetzner VPS**

- 30 minutes setup
- $5/month
- Perfect reproducibility
- SQLite works natively
- Easy to maintain

You get the best of both worlds: **reproducibility of Docker** with **simplicity of native deployment**.

---

## Next Steps

Want me to create:

1. ✅ Complete renv setup script
2. ✅ Hetzner deployment script with renv
3. ✅ Testing procedures
4. ✅ Update workflow documentation

Let me know and I'll generate production-ready files!
