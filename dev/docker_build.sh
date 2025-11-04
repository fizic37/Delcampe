#!/bin/bash
# Delcampe Docker Build Script
# Builds Docker image with version tagging

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Delcampe Docker Build${NC}"
echo -e "${GREEN}========================================${NC}"

# Get version from DESCRIPTION file
if [ ! -f "DESCRIPTION" ]; then
    echo -e "${RED}ERROR: DESCRIPTION file not found!${NC}"
    echo "Make sure you're running this from the project root directory."
    exit 1
fi

VERSION=$(grep "^Version:" DESCRIPTION | awk '{print $2}')
if [ -z "$VERSION" ]; then
    echo -e "${RED}ERROR: Could not extract version from DESCRIPTION${NC}"
    exit 1
fi

echo -e "${YELLOW}Building version: ${VERSION}${NC}"
echo ""

# Build Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
docker build \
    --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
    --build-arg VERSION=${VERSION} \
    -t delcampe-app:latest \
    -t delcampe-app:${VERSION} \
    .

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Build successful!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "Image tags:"
    echo -e "  - ${YELLOW}delcampe-app:latest${NC}"
    echo -e "  - ${YELLOW}delcampe-app:${VERSION}${NC}"
    echo ""
    echo -e "Image size:"
    docker images delcampe-app:latest --format "  {{.Size}}"
    echo ""
else
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi
