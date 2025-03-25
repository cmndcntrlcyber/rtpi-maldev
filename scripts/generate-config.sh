#!/bin/bash
# DevOps Stack - Configuration Generator Script
set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
echo "========================================================"
echo "   DevOps Stack - Configuration Generator"
echo "========================================================"
echo -e "${NC}"

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}Note: Running without root privileges.${NC}"
  sleep 1
fi

# Function to generate Nginx configuration
generate_nginx_config() {
  local domain=$1
  echo -e "${BLUE}Generating Nginx configuration for $domain...${NC}"
  
  # Create configs directory if it doesn't exist
  mkdir -p config/nginx/sites
  
  # Create main Nginx config
  cat > config/nginx/nginx.conf << EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    keepalive_timeout 65;
    
    # SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    include /etc/nginx/conf.d/*.conf;
}
EOF

  # Create vhost configs for services
  for service in gitea drone-server portainer kasm_manager; do
    local service_name=${service/-/_}
    local subdomain="${service_name/_manager/}"
    local port
    
    case $service_name in
      gitea) port=3000 ;;
      drone_server) port=80 ;;
      portainer) port=9000 ;;
      kasm_manager) port=8443; subdomain="kasm" ;;
    esac
    
    local ssl_config=""
    if [ "$use_ssl" = "true" ]; then
      ssl_config="
    listen 443 ssl;
    ssl_certificate /etc/nginx/certs/${subdomain}.${domain}.crt;
    ssl_certificate_key /etc/nginx/certs/${subdomain}.${domain}.key;
    
    # Redirect HTTP to HTTPS
    listen 80;
    if (\$scheme = http) {
        return 301 https://\$host\$request_uri;
    }"
    else
      ssl_config="
    listen 80;"
    fi
    
    # Special case for Kasm (WebSocket and HTTPS backend)
    if [ "$service_name" = "kasm_manager" ]; then
      cat > config/nginx/sites/${subdomain}.conf << EOF
server {
    server_name ${subdomain}.${domain};
    ${ssl_config}
    
    location / {
        proxy_pass https://${service}:${port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Increase timeouts for long-lived connections
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        
        # SSL verification
        proxy_ssl_verify off;
    }
}
EOF
    else
      cat > config/nginx/sites/${subdomain}.conf << EOF
server {
    server_name ${subdomain}.${domain};
    ${ssl_config}
    
    location / {
        proxy_pass http://${service}:${port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    fi
    
    echo -e "${GREEN}✓ Generated ${subdomain}.conf${NC}"
  done
  
  echo -e "${GREEN}Nginx configuration completed.${NC}"
}

# Function to generate Portainer admin password file
generate_portainer_password() {
  local password=$1
  echo -e "${BLUE}Generating Portainer admin password file...${NC}"
  
  mkdir -p config/portainer
  echo -n "$password" > config/portainer/admin_password.txt
  chmod 600 config/portainer/admin_password.txt
  
  echo -e "${GREEN}Portainer admin password file created.${NC}"
}

# Function to generate random string
generate_random() {
  local length=$1
  local type=$2
  
  if [ "$type" = "hex" ]; then
    openssl rand -hex $length
  else
    openssl rand -base64 $length
  fi
}

# Function to prompt for value with default
prompt_with_default() {
  local prompt=$1
  local default=$2
  local variable=$3
  
  read -p "$prompt [$default]: " input
  # Use default if input is empty
  local value=${input:-$default}
  # Export the variable
  export $variable="$value"
  echo $value
}

# Interactive configuration
echo -e "${BLUE}Starting interactive configuration...${NC}"

# Domain configuration
domain=$(prompt_with_default "Enter your domain name" "devops.local" "DOMAIN")

# SSL configuration
read -p "Use SSL/HTTPS? (y/n) [n]: " ssl_input
use_ssl=${ssl_input:-n}
if [[ $use_ssl =~ ^[Yy]$ ]]; then
  use_ssl="true"
  echo -e "${YELLOW}Note: You'll need to provide SSL certificates for each subdomain.${NC}"
else
  use_ssl="false"
fi
export USE_SSL=$use_ssl

# Generate admin credentials
echo -e "\n${BLUE}Generating secure credentials...${NC}"
admin_password=$(generate_random 12 "base64")
gitea_secret=$(generate_random 16 "hex")
drone_secret=$(generate_random 16 "hex")
kasm_db_password=$(generate_random 12 "hex")
redis_password=$(generate_random 12 "hex")
webhook_secret=$(generate_random 12 "hex")

# Create .env file
echo -e "${BLUE}Creating .env file...${NC}"

cat > .env << EOF
# DevOps Stack Environment Variables
# Generated on $(date)

# Domain Configuration
DOMAIN=${domain}
USE_SSL=${use_ssl}

# Gitea Configuration
GITEA_DOMAIN=gitea.${domain}
GITEA_SSH_PORT=222
GITEA_SECRET=${gitea_secret}
GITEA_ADMIN_USER=gitadmin
GITEA_ADMIN_PASSWORD=${admin_password}
GITEA_ADMIN_EMAIL=admin@${domain}

# Drone Configuration
DRONE_DOMAIN=drone.${domain}
DRONE_RPC_SECRET=${drone_secret}
DRONE_GITEA_CLIENT_ID=
DRONE_GITEA_CLIENT_SECRET=
DRONE_ADMIN_USER=gitadmin

# Portainer Configuration
PORTAINER_DOMAIN=portainer.${domain}
PORTAINER_ADMIN_PASSWORD=${admin_password}

# Kasm Configuration
KASM_DOMAIN=kasm.${domain}
KASM_DB_PASSWORD=${kasm_db_password}
KASM_REDIS_PASSWORD=${redis_password}
KASM_ADMIN_USER=admin@${domain}
KASM_ADMIN_PASSWORD=${admin_password}
KASM_MANAGER_API_KEY=

# Webhook Configuration
WEBHOOK_SECRET=${webhook_secret}

# Network Configuration
SUBNET=172.18.0.0/16
EOF

echo -e "${GREEN}✓ .env file created${NC}"

# Generate Nginx configuration
generate_nginx_config $domain

# Generate Portainer password file
generate_portainer_password $admin_password

# Create empty Kasm configuration files
mkdir -p config/kasm
touch config/kasm/manager.conf
touch config/kasm/agent.conf

# Create Gitea app.ini template file
mkdir -p config/gitea
cat > config/gitea/app.ini << EOF
; Gitea Custom Configuration

[server]
DOMAIN = gitea.${domain}
ROOT_URL = http://gitea.${domain}/
SSH_DOMAIN = gitea.${domain}
SSH_PORT = 222
HTTP_PORT = 3000
DISABLE_SSH = false
SSH_LISTEN_PORT = 22

[database]
DB_TYPE = sqlite3
PATH = /data/gitea/gitea.db

[repository]
ROOT = /data/git/repositories

[security]
INSTALL_LOCK = true
SECRET_KEY = ${gitea_secret}

[service]
DISABLE_REGISTRATION = false
REQUIRE_SIGNIN_VIEW = false
REGISTER_EMAIL_CONFIRM = false
ENABLE_NOTIFY_MAIL = false

[mailer]
ENABLED = false

[oauth2]
JWT_SECRET = ${gitea_secret}
EOF

echo -e "${GREEN}✓ Gitea configuration template created${NC}"

# Create empty Drone configuration file
mkdir -p config/drone
touch config/drone/.env.drone

# Summary
echo -e "\n${GREEN}========================================================"
echo " Configuration Generated Successfully!"
echo "========================================================${NC}"
echo -e "Domain: ${YELLOW}${domain}${NC}"
echo -e "SSL/HTTPS: ${YELLOW}${use_ssl}${NC}"
echo -e "Admin password: ${YELLOW}${admin_password}${NC}"
echo -e "\n${YELLOW}Important notes:${NC}"
echo "1. The admin password is stored in the .env file"
echo "2. Save this password in a secure location"
echo "3. You'll need to update the Drone OAuth credentials after setting up Gitea"
echo "4. After starting Kasm, get the API key from the logs and update the .env file"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Review the generated configuration files in the config/ directory"
echo "2. Start the services with: docker-compose up -d"
echo "3. Access Gitea at: http://gitea.${domain}"
echo "4. Access Drone at: http://drone.${domain}"
echo "5. Access Portainer at: http://portainer.${domain}"
echo "6. Access Kasm at: http://kasm.${domain}"