#!/bin/bash
# DevOps Stack - Monitoring Script
set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
  echo -e "\n${BLUE}========================================================${NC}"
  echo -e "${BLUE} $1 ${NC}"
  echo -e "${BLUE}========================================================${NC}"
}

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
  echo -e "${RED}Error: docker-compose.yml not found in current directory${NC}"
  echo -e "Please run this script from the project root directory."
  exit 1
fi

# Print banner
echo -e "${CYAN}"
echo "========================================================"
echo "   DevOps Stack - Monitoring Dashboard"
echo "========================================================"
echo "   $(date)"
echo "========================================================"
echo -e "${NC}"

# Get container status
print_header "Container Status"
docker-compose ps

# Check for stopped containers
STOPPED_CONTAINERS=$(docker-compose ps | grep -v "running" | grep -v "NAME" | wc -l)
if [ $STOPPED_CONTAINERS -gt 0 ]; then
  echo -e "\n${YELLOW}Warning: $STOPPED_CONTAINERS containers are not running.${NC}"
else
  echo -e "\n${GREEN}All containers are running.${NC}"
fi

# Get resource usage
print_header "Resource Usage"
docker stats --no-stream $(docker-compose ps -q) 2>/dev/null || echo -e "${YELLOW}No running containers found.${NC}"

# Get disk usage
print_header "Disk Usage"
echo -e "${CYAN}Overall disk usage:${NC}"
df -h $(pwd) | grep -v "Filesystem"

# Get volume sizes
print_header "Volume Sizes"
VOLUMES=$(docker volume ls --filter name=devops-stack -q 2>/dev/null || docker volume ls -q)
if [ -z "$VOLUMES" ]; then
  echo -e "${YELLOW}No Docker volumes found.${NC}"
else
  for volume in $VOLUMES; do
    SIZE=$(docker run --rm -v $volume:/vol alpine sh -c "du -sh /vol | cut -f1")
    echo -e "${CYAN}$volume:${NC} $SIZE"
  done
fi

# Get container logs summary
print_header "Recent Logs Summary"
echo -e "${YELLOW}Last 5 log entries from each container:${NC}"
for container in $(docker-compose ps -q); do
  CONTAINER_NAME=$(docker inspect --format '{{.Name}}' $container | sed 's/\///')
  echo -e "\n${CYAN}$CONTAINER_NAME:${NC}"
  docker logs --tail=5 $container 2>&1 | sed 's/^/  /'
done

# Monitor network connections
print_header "Network Connections"
echo -e "${CYAN}Active container network connections:${NC}"
for container in $(docker-compose ps -q); do
  CONTAINER_NAME=$(docker inspect --format '{{.Name}}' $container | sed 's/\///')
  NETWORK_CONNECTIONS=$(docker exec $container netstat -tun 2>/dev/null | grep -v "Active\|Proto" | wc -l || echo "N/A")
  if [ "$NETWORK_CONNECTIONS" != "N/A" ]; then
    echo -e "${CYAN}$CONTAINER_NAME:${NC} $NETWORK_CONNECTIONS connections"
  fi
done

# Get container health status
print_header "Container Health Checks"
for container in $(docker-compose ps -q); do
  CONTAINER_NAME=$(docker inspect --format '{{.Name}}' $container | sed 's/\///')
  HEALTH_STATUS=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}No health check{{end}}' $container 2>/dev/null || echo "N/A")
  
  if [ "$HEALTH_STATUS" = "healthy" ]; then
    echo -e "${CYAN}$CONTAINER_NAME:${NC} ${GREEN}$HEALTH_STATUS${NC}"
  elif [ "$HEALTH_STATUS" = "unhealthy" ]; then
    echo -e "${CYAN}$CONTAINER_NAME:${NC} ${RED}$HEALTH_STATUS${NC}"
  else
    echo -e "${CYAN}$CONTAINER_NAME:${NC} ${YELLOW}$HEALTH_STATUS${NC}"
  fi
done

# Print system info
print_header "System Information"
echo -e "${CYAN}Docker Engine:${NC} $(docker --version)"
echo -e "${CYAN}Docker Compose:${NC} $(docker-compose --version)"
echo -e "${CYAN}System Uptime:${NC} $(uptime | cut -d ',' -f1)"

# Check for updates
print_header "Available Updates"
echo -e "${YELLOW}Checking for container image updates...${NC}"
OUTDATED=0

for service in $(docker-compose config --services); do
  # Get image name
  IMAGE=$(docker-compose config | grep -A 2 "$service:" | grep "image:" | awk '{print $2}')
  
  # Skip if service uses a build directive instead of image
  if [ -z "$IMAGE" ]; then
    echo -e "${CYAN}$service:${NC} ${YELLOW}Uses local build${NC}"
    continue
  fi
  
  # Check if image exists locally
  if docker image inspect $IMAGE >/dev/null 2>&1; then
    # Pull latest image info
    docker pull $IMAGE >/dev/null 2>&1 || { echo -e "${CYAN}$service:${NC} ${RED}Failed to check for updates${NC}"; continue; }
    
    # Get local and remote digests
    LOCAL_DIGEST=$(docker image inspect --format='{{index .RepoDigests 0}}' $IMAGE 2>/dev/null || echo "")
    REMOTE_DIGEST=$(docker image inspect --format='{{index .RepoDigests 0}}' $IMAGE 2>/dev/null || echo "")
    
    if [ "$LOCAL_DIGEST" != "$REMOTE_DIGEST" ] && [ -n "$LOCAL_DIGEST" ] && [ -n "$REMOTE_DIGEST" ]; then
      echo -e "${CYAN}$service:${NC} ${YELLOW}Update available${NC}"
      OUTDATED=$((OUTDATED+1))
    else
      echo -e "${CYAN}$service:${NC} ${GREEN}Up to date${NC}"
    fi
  else
    echo -e "${CYAN}$service:${NC} ${YELLOW}Image not found locally${NC}"
  fi
done

if [ $OUTDATED -gt 0 ]; then
  echo -e "\n${YELLOW}$OUTDATED services have updates available. Run ./scripts/update.sh to update.${NC}"
else
  echo -e "\n${GREEN}All services are up to date.${NC}"
fi

# Print monitoring summary
print_header "Monitoring Summary"
echo -e "${GREEN}Monitoring completed at $(date)${NC}"
echo -e "${YELLOW}For live monitoring, use:${NC} docker stats"
echo -e "${YELLOW}For container logs, use:${NC} docker-compose logs -f [service]"
echo -e "${YELLOW}For system monitoring, use:${NC} htop, nmon, or glances"