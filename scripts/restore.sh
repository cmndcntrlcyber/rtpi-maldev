#!/bin/bash
# DevOps Stack - Restore Script
set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if backup directory is provided
if [ $# -ne 1 ]; then
  echo -e "${RED}Error: Backup directory not specified${NC}"
  echo -e "Usage: $0 <backup_directory>"
  echo -e "Example: $0 ./backups/20230101_120000"
  exit 1
fi

BACKUP_DIR=$1

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
  echo -e "${RED}Error: Backup directory does not exist: $BACKUP_DIR${NC}"
  exit 1
fi

echo -e "${BLUE}========================================================${NC}"
echo -e "${BLUE} DevOps Stack - Restore from Backup${NC}"
echo -e "${BLUE}========================================================${NC}"
echo -e "${YELLOW}Backup source: $BACKUP_DIR${NC}"

# Confirm before proceeding
echo -e "${RED}WARNING: This will overwrite your current configuration and data.${NC}"
read -p "Do you want to continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW}Restore cancelled.${NC}"
  exit 0
fi

# Stop containers
echo -e "${BLUE}Stopping containers...${NC}"
docker-compose down

# Restore .env file
echo -e "${BLUE}Restoring .env file...${NC}"
if [ -f "$BACKUP_DIR/.env" ]; then
  cp $BACKUP_DIR/.env ./.env
  echo -e "${GREEN}✓ .env file restored${NC}"
else
  echo -e "${YELLOW}⚠ .env file not found in backup${NC}"
fi

# Restore docker-compose.yml
echo -e "${BLUE}Restoring docker-compose.yml file...${NC}"
if [ -f "$BACKUP_DIR/docker-compose.yml" ]; then
  cp $BACKUP_DIR/docker-compose.yml ./docker-compose.yml
  echo -e "${GREEN}✓ docker-compose.yml file restored${NC}"
else
  echo -e "${YELLOW}⚠ docker-compose.yml file not found in backup${NC}"
fi

# Restore config directory
echo -e "${BLUE}Restoring config directory...${NC}"
if [ -d "$BACKUP_DIR/config" ]; then
  rm -rf ./config
  cp -r $BACKUP_DIR/config ./
  echo -e "${GREEN}✓ config directory restored${NC}"
else
  echo -e "${YELLOW}⚠ config directory not found in backup${NC}"
fi

# Restore custom directory
echo -e "${BLUE}Restoring custom directory...${NC}"
if [ -d "$BACKUP_DIR/custom" ]; then
  rm -rf ./custom
  cp -r $BACKUP_DIR/custom ./
  echo -e "${GREEN}✓ custom directory restored${NC}"
else
  echo -e "${YELLOW}⚠ custom directory not found in backup${NC}"
fi

# Restore Docker volumes
if [ -d "$BACKUP_DIR/volumes" ]; then
  echo -e "${BLUE}Restoring Docker volumes...${NC}"
  
  # Get list of volume backup files
  VOLUME_BACKUPS=$(ls $BACKUP_DIR/volumes/*.tar.gz 2>/dev/null || echo "")
  
  if [ -z "$VOLUME_BACKUPS" ]; then
    echo -e "${YELLOW}⚠ No volume backups found${NC}"
  else
    for backup_file in $VOLUME_BACKUPS; do
      # Extract volume name from filename
      volume_name=$(basename $backup_file .tar.gz)
      echo -e "${BLUE}Restoring volume: $volume_name${NC}"
      
      # Ensure volume exists
      docker volume create $volume_name 2>/dev/null || true
      
      # Restore volume data
      if docker run --rm -v $volume_name:/target -v $BACKUP_DIR/volumes:/backup alpine sh -c "rm -rf /target/* && tar -xzf /backup/$(basename $backup_file) -C /target"; then
        echo -e "${GREEN}✓ Volume $volume_name restored successfully${NC}"
      else
        echo -e "${RED}✗ Failed to restore volume $volume_name${NC}"
      fi
    done
  fi
else
  echo -e "${YELLOW}⚠ No volumes directory found in backup${NC}"
fi

# Fix permissions if needed
echo -e "${BLUE}Setting correct permissions...${NC}"
find ./scripts -name "*.sh" -exec chmod +x {} \;

# Start containers
echo -e "${BLUE}Starting containers...${NC}"
docker-compose up -d

# Display summary
echo -e "\n${GREEN}========================================================"
echo " Restore Completed!"
echo "========================================================${NC}"
echo -e "Restored from: ${YELLOW}$BACKUP_DIR${NC}"
echo -e "\n${BLUE}Container status:${NC}"
docker-compose ps

echo -e "\n${YELLOW}Note: If any containers failed to start, check the logs:${NC}"
echo -e "${BLUE}docker-compose logs <service-name>${NC}"