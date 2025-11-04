#!/bin/bash
# Delcampe Docker Deployment Script
# Deploys Docker container with health checks

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Delcampe Docker Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check for .env.production
if [ ! -f ".env.production" ]; then
    echo -e "${RED}ERROR: .env.production not found!${NC}"
    echo "Please create .env.production with your production credentials."
    echo "See .env.production.template for format."
    exit 1
fi

echo -e "${YELLOW}Environment file found: .env.production${NC}"
echo ""

# Pull latest code (if in git repo)
if [ -d ".git" ]; then
    echo -e "${YELLOW}Pulling latest code from git...${NC}"
    git pull || echo -e "${YELLOW}Warning: git pull failed or already up to date${NC}"
    echo ""
fi

# Build Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
./dev/docker_build.sh
echo ""

# Stop old container
echo -e "${YELLOW}Stopping old container (if running)...${NC}"
docker-compose down || echo -e "${YELLOW}No container to stop${NC}"
echo ""

# Start new container
echo -e "${YELLOW}Starting new container...${NC}"
docker-compose up -d

# Wait for health check (60 seconds max)
echo ""
echo -e "${YELLOW}Waiting for health check (60 seconds max)...${NC}"
for i in {1..12}; do
    sleep 5
    HEALTH=$(docker inspect --format='{{.State.Health.Status}}' delcampe-app 2>/dev/null || echo "none")
    if [ "$HEALTH" = "healthy" ]; then
        echo -e "${GREEN}Container is healthy!${NC}"
        break
    fi
    echo -e "  Health check attempt $i/12: $HEALTH"
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Show container status
echo -e "${YELLOW}Container status:${NC}"
docker-compose ps
echo ""

# Show recent logs
echo -e "${YELLOW}Recent logs:${NC}"
docker-compose logs --tail=20
echo ""

echo -e "${GREEN}Application should be accessible at:${NC}"
echo -e "  http://localhost:3838 (local)"
echo -e "  http://YOUR_SERVER_IP:3838 (if on remote server)"
echo ""
echo -e "${YELLOW}To view live logs:${NC}"
echo -e "  docker-compose logs -f"
echo ""
