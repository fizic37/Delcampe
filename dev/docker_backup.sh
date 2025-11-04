#!/bin/bash
# Delcampe Docker Database Backup Script
# Backs up SQLite database from Docker volume

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Delcampe Database Backup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Configuration
VOLUME_PATH="/mnt/delcampe-data/sqlite"
DB_FILE="tracking.sqlite"
BACKUP_DIR="/root/delcampe-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="tracking_${TIMESTAMP}.sqlite.gz"

# Check if volume is mounted
if [ ! -d "$VOLUME_PATH" ]; then
    echo -e "${RED}ERROR: Volume not found at $VOLUME_PATH${NC}"
    echo "Make sure you're running this on the Hetzner server with the volume mounted."
    exit 1
fi

# Check if database exists
if [ ! -f "$VOLUME_PATH/$DB_FILE" ]; then
    echo -e "${RED}ERROR: Database not found at $VOLUME_PATH/$DB_FILE${NC}"
    exit 1
fi

echo -e "${YELLOW}Database found: $VOLUME_PATH/$DB_FILE${NC}"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Create backup
echo -e "${YELLOW}Creating backup...${NC}"
cp "$VOLUME_PATH/$DB_FILE" "/tmp/$DB_FILE"
gzip -c "/tmp/$DB_FILE" > "$BACKUP_DIR/$BACKUP_FILE"
rm "/tmp/$DB_FILE"

# Check backup succeeded
if [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | awk '{print $1}')
    echo -e "${GREEN}Backup created successfully!${NC}"
    echo -e "  Location: $BACKUP_DIR/$BACKUP_FILE"
    echo -e "  Size: $BACKUP_SIZE"
else
    echo -e "${RED}Backup failed!${NC}"
    exit 1
fi

# Keep only last 7 backups
echo ""
echo -e "${YELLOW}Cleaning up old backups (keeping last 7)...${NC}"
cd "$BACKUP_DIR"
ls -t tracking_*.sqlite.gz | tail -n +8 | xargs -r rm --
BACKUP_COUNT=$(ls -1 tracking_*.sqlite.gz | wc -l)
echo -e "  Backups remaining: $BACKUP_COUNT"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Backup Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# List all backups
echo -e "${YELLOW}All backups:${NC}"
ls -lh "$BACKUP_DIR"/tracking_*.sqlite.gz
echo ""
