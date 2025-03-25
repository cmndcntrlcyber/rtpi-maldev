#!/bin/bash
# DevOps Stack - Cleanup Script
set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${RED}"
echo "========================================================"
echo "   DevOps Stack - Cleanup Script"
echo "========================================================"
echo -e "${NC}"

# Warning
echo -e "${RED}WARNING: This script will remove containers, volumes, and configuration files.${NC}"
echo -e "${RED}         Data will be lost unless you have created backups.${NC}"
echo -e "${YELLOW}         Please create a backup first if you want to preserve your data.${NC}"
echo

# Ask for confirmation
read -p "Do you want to continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${GREEN}Cleanup cancelled.${NC}"
  exit 0
fi

# Additional confirmation for volume deletion
read -p "Remove Docker volumes? This will DELETE ALL DATA (y/n): " -n 1 -r
echo
REMOVE_VOLUMES=$REPLY

# Check if docker-compose.yml exists
if [ -f "docker-compose.yml" ]; then
  echo -e "${BLUE}Stopping and removing containers...${NC}"
  docker-compose down
  echo -e "${GREEN}✓ Containers stopped and removed${NC}"
else
  echo -e "${YELLOW}docker-compose.yml not found. Skipping container removal.${NC}"
fi

# Remove Docker volumes if confirmed
if [[ $REMOVE_VOLUMES =~ ^[Yy]$ ]]; then
  echo -e "${BLUE}Removing Docker volumes...${NC}"
  # Get list of volumes
  VOLUMES=$(docker volume ls --filter name=devops-stack -q 2>/dev/null || echo "")
  
  if [ -z "$VOLUMES" ]; then
    echo -e "${YELLOW}No Docker volumes found.${NC}"
  else
    for volume in $VOLUMES; do
      echo -e "${BLUE}Removing volume: $volume${NC}"
      docker volume rm $volume
    done
    echo -e "${GREEN}✓ Docker volumes removed${NC}"
  fi
else
  echo -e "${YELLOW}Skipping volume removal.${NC}"
fi

# Ask about removing configuration files
read -p "Remove configuration files and directories? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${BLUE}Removing configuration files and directories...${NC}"
  
  # Remove config directories
  if [ -d "config" ]; then
    rm -rf config
    echo -e "${GREEN}✓ Config directory removed${NC}"
  fi
  
  # Remove .env file
  if [ -f ".env" ]; then
    rm .env
    echo -e "${GREEN}✓ .env file removed${NC}"
  fi
  
  # Remove custom directory
  if [ -d "custom" ]; then
    rm -rf custom
    echo -e "${GREEN}✓ Custom directory removed${NC}"
  fi
else
  echo -e "${YELLOW}Skipping configuration file removal.${NC}"
fi

# Ask about removing backup files
if [ -d "backups" ]; then
  read -p "Remove backup files? (y/n): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Removing backup files...${NC}"
    rm -rf backups
    echo -e "${GREEN}✓ Backup files removed${NC}"
  else
    echo -e "${YELLOW}Skipping backup file removal.${NC}"
  fi
fi

# Clean up Docker system
read -p "Clean up unused Docker resources (images, networks)? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${BLUE}Cleaning up Docker system resources...${NC}"
  
  # Remove unused networks
  echo -e "${BLUE}Removing unused networks...${NC}"
  docker network prune -f
  
  # Remove dangling images
  echo -e "${BLUE}Removing dangling images...${NC}"
  docker image prune -f
  
  echo -e "${GREEN}✓ Docker system cleaned up${NC}"
fi

# Remove entire directory
read -p "Remove the entire DevOps stack directory? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${RED}This will delete EVERYTHING in the current directory.${NC}"
  read -p "Are you ABSOLUTELY sure? Type 'yes' to confirm: " confirm
  if [ "$confirm" = "yes" ]; then
    echo -e "${BLUE}Removing DevOps stack directory...${NC}"
    cd ..
    rm -rf $(basename $(pwd))
    echo -e "${GREEN}✓ DevOps stack directory removed${NC}"
    echo -e "${GREEN}Cleanup completed. Goodbye!${NC}"
    exit 0
  else
    echo -e "${YELLOW}Directory removal cancelled.${NC}"
  fi
fi

# Display cleanup summary
echo -e "\n${GREEN}========================================================"
echo " Cleanup Completed!"
echo "========================================================${NC}"
echo -e "Performed at: $(date)"

echo -e "\n${BLUE}Summary:${NC}"
echo -e "- Containers and images: ${GREEN}Removed${NC}"
if [[ $REMOVE_VOLUMES =~ ^[Yy]$ ]]; then
  echo -e "- Docker volumes: ${GREEN}Removed${NC}"
else
  echo -e "- Docker volumes: ${YELLOW}Preserved${NC}"
fi

echo -e "\n${YELLOW}To completely start fresh, you may want to remove the directory manually.${NC}"
echo -e "${YELLOW}To reinstall, run the setup script again.${NC}"