#!/bin/bash
# DevOps Stack - Update Script
set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================================${NC}"
echo -e "${BLUE} DevOps Stack - Update Containers${NC}"
echo -e "${BLUE}========================================================${NC}"

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
  echo -e "${RED}Error: docker-compose.yml not found in current directory${NC}"
  echo -e "Please run this script from the project root directory."
  exit 1
fi

# Recommend backup before update
echo -e "${YELLOW}It's recommended to create a backup before updating.${NC}"
read -p "Create backup before proceeding? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${BLUE}Creating backup...${NC}"
  ./scripts/backup.sh
  echo -e "${GREEN}Backup created. Continuing with update...${NC}"
fi

# Pull latest images
echo -e "${BLUE}Pulling latest images...${NC}"
docker-compose pull

# Check for custom build services
BUILD_SERVICES=$(grep -E "^\s+build:" docker-compose.yml | wc -l)
if [ $BUILD_SERVICES -gt 0 ]; then
  echo -e "${BLUE}Rebuilding custom services...${NC}"
  docker-compose build --pull
fi

# Stop and remove containers (but keep volumes)
echo -e "${BLUE}Stopping and removing containers...${NC}"
docker-compose down

# Start services with new images
echo -e "${BLUE}Starting services with updated images...${NC}"
docker-compose up -d

# Check container health
echo -e "${BLUE}Checking container health...${NC}"
sleep 10 # Give containers time to initialize

# Display container status
echo -e "${BLUE}Container status:${NC}"
docker-compose ps

# Check if any containers are not running
NOT_RUNNING=$(docker-compose ps | grep -v "running" | grep -v "NAME" | wc -l)
if [ $NOT_RUNNING -gt 0 ]; then
  echo -e "${YELLOW}Warning: Some containers are not running. Check the logs:${NC}"
  echo -e "${BLUE}docker-compose logs <service-name>${NC}"
else
  echo -e "${GREEN}All containers are running.${NC}"
fi

# Display update summary
echo -e "\n${GREEN}========================================================"
echo " Update Completed!"
echo "========================================================${NC}"
echo -e "Updated on: $(date)"

# Provide next steps
echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "1. Check logs for any errors: ${BLUE}docker-compose logs${NC}"
echo -e "2. Verify all services are working correctly"
echo -e "3. If you encounter issues, restore from backup: ${BLUE}./scripts/restore.sh <backup-dir>${NC}"

# Check Kasm API key if we updated Kasm
if grep -q "kasm_manager" docker-compose.yml && grep -q "kasm_agent" docker-compose.yml; then
  echo -e "\n${YELLOW}Note: If you updated Kasm Workspaces, you may need to update the API key:${NC}"
  echo -e "1. Get the new API key: ${BLUE}docker logs kasm_manager | grep \"API KEY\"${NC}"
  echo -e "2. Update your .env file with the new key"
  echo -e "3. Restart the Kasm agent: ${BLUE}docker-compose restart kasm_agent${NC}"
fi