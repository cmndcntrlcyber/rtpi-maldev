#!/bin/bash
# DevOps Stack - Backup Script
set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}Warning: Running without root privileges. Some files might not be backed up properly.${NC}"
  sleep 2
fi

# Create backup directory with timestamp
BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR
echo -e "${BLUE}Creating backup in: $BACKUP_DIR${NC}"

# Backup .env file
echo -e "${BLUE}Backing up .env file...${NC}"
if [ -f .env ]; then
  cp .env $BACKUP_DIR/
  echo -e "${GREEN}✓ .env file backed up${NC}"
else
  echo -e "${YELLOW}⚠ .env file not found${NC}"
fi

# Backup docker-compose.yml
echo -e "${BLUE}Backing up docker-compose.yml file...${NC}"
if [ -f docker-compose.yml ]; then
  cp docker-compose.yml $BACKUP_DIR/
  echo -e "${GREEN}✓ docker-compose.yml file backed up${NC}"
else
  echo -e "${YELLOW}⚠ docker-compose.yml file not found${NC}"
fi

# Backup config directory
echo -e "${BLUE}Backing up config directory...${NC}"
if [ -d config ]; then
  cp -r config $BACKUP_DIR/
  echo -e "${GREEN}✓ config directory backed up${NC}"
else
  echo -e "${YELLOW}⚠ config directory not found${NC}"
fi

# Backup custom directory
echo -e "${BLUE}Backing up custom directory...${NC}"
if [ -d custom ]; then
  cp -r custom $BACKUP_DIR/
  echo -e "${GREEN}✓ custom directory backed up${NC}"
else
  echo -e "${YELLOW}⚠ custom directory not found${NC}"
fi

# Stop containers to ensure data consistency
echo -e "${BLUE}Stopping containers to ensure data consistency...${NC}"
docker-compose down

# Get list of volumes
echo -e "${BLUE}Identifying volumes to back up...${NC}"
VOLUMES=$(docker volume ls --filter name=devops-stack -q 2>/dev/null || docker volume ls -q)
if [ -z "$VOLUMES" ]; then
  echo -e "${YELLOW}⚠ No Docker volumes found${NC}"
else
  # Create volume backups directory
  mkdir -p $BACKUP_DIR/volumes
  
  # Backup each volume
  for volume in $VOLUMES; do
    echo -e "${BLUE}Backing up volume: $volume${NC}"
    # Use temporary container to backup volume
    if docker run --rm -v $volume:/source -v $(pwd)/$BACKUP_DIR/volumes:/backup alpine tar -czf /backup/$volume.tar.gz -C /source .; then
      echo -e "${GREEN}✓ Volume $volume backed up successfully${NC}"
    else
      echo -e "${RED}✗ Failed to backup volume $volume${NC}"
    fi
  done
fi

# Restart containers
echo -e "${BLUE}Restarting containers...${NC}"
docker-compose up -d

# Create backup info file
echo -e "${BLUE}Creating backup info file...${NC}"
cat > $BACKUP_DIR/backup_info.txt << EOL
DevOps Stack Backup
Created on: $(date)
Hostname: $(hostname)
Docker version: $(docker --version)
Docker Compose version: $(docker-compose --version)

Contents:
- Configuration files
- Docker volumes
- Custom Dockerfiles and code
EOL

# Calculate backup size
BACKUP_SIZE=$(du -sh $BACKUP_DIR | cut -f1)

# Display summary
echo -e "\n${GREEN}========================================================"
echo " Backup Completed Successfully!"
echo "========================================================${NC}"
echo -e "Backup location: ${YELLOW}$BACKUP_DIR${NC}"
echo -e "Backup size: ${YELLOW}$BACKUP_SIZE${NC}"
echo -e "\nTo restore from this backup, run:"
echo -e "${BLUE}./scripts/restore.sh $BACKUP_DIR${NC}"
echo -e "\n${YELLOW}Note: Keep your backups secure as they may contain sensitive information.${NC}"