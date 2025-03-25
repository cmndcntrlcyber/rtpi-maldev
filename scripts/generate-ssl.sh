#!/bin/bash
# DevOps Stack - SSL Certificate Generator Script
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
echo "   DevOps Stack - SSL Certificate Generator"
echo "========================================================"
echo -e "${NC}"

# Check if OpenSSL is installed
if ! command -v openssl &> /dev/null; then
  echo -e "${RED}Error: OpenSSL is not installed. Please install it first.${NC}"
  exit 1
fi

# Load environment variables
if [ -f .env ]; then
  source .env
else
  echo -e "${RED}Error: .env file not found. Please run setup.sh first.${NC}"
  exit 1
fi

# Ensure the domain is set
if [ -z "$DOMAIN" ]; then
  echo -e "${RED}Error: DOMAIN not set in .env file.${NC}"
  exit 1
fi

# Function to generate a self-signed certificate
generate_self_signed() {
  local domain=$1
  local output_dir=$2
  local common_name=$domain
  
  echo -e "${BLUE}Generating self-signed certificate for ${domain}...${NC}"
  
  # Create output directory
  mkdir -p "$output_dir"
  
  # Generate private key
  openssl genrsa -out "${output_dir}/${domain}.key" 2048
  
  # Create CSR configuration
  cat > "${output_dir}/${domain}.cnf" << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C=US
ST=State
L=City
O=DevOps Stack
OU=DevOps
CN=${common_name}

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${domain}
DNS.2 = *.${domain}
EOF
  
  # Generate CSR
  openssl req -new -key "${output_dir}/${domain}.key" -out "${output_dir}/${domain}.csr" -config "${output_dir}/${domain}.cnf"
  
  # Generate self-signed certificate
  openssl x509 -req -days 365 -in "${output_dir}/${domain}.csr" -signkey "${output_dir}/${domain}.key" -out "${output_dir}/${domain}.crt" -extensions req_ext -extfile "${output_dir}/${domain}.cnf"
  
  echo -e "${GREEN}✓ Self-signed certificate generated for ${domain}${NC}"
}

# Function to generate certificates for each service
generate_certificates() {
  local base_domain=$1
  local cert_dir=$2
  local method=$3
  
  # Create certificates directory
  mkdir -p "$cert_dir"
  
  if [ "$method" = "self-signed" ]; then
    # Generate main wildcard certificate
    generate_self_signed "*.$base_domain" "$cert_dir"
    
    # Create symbolic links for each service
    for service in gitea drone portainer kasm; do
      ln -sf "${cert_dir}/*.$base_domain.crt" "${cert_dir}/${service}.$base_domain.crt"
      ln -sf "${cert_dir}/*.$base_domain.key" "${cert_dir}/${service}.$base_domain.key"
      echo -e "${GREEN}✓ Created symbolic link for ${service}.$base_domain${NC}"
    done
  elif [ "$method" = "letsencrypt" ]; then
    echo -e "${YELLOW}Let's Encrypt certificates need to be obtained separately.${NC}"
    echo -e "${YELLOW}Please follow the instructions in the documentation.${NC}"
  else
    echo -e "${RED}Error: Invalid certificate method: $method${NC}"
    exit 1
  fi
}

# Main script
echo -e "${BLUE}SSL/TLS Certificate Generator${NC}"
echo -e "Domain: ${YELLOW}${DOMAIN}${NC}"

# Check if Nginx config directory exists
NGINX_CERTS_DIR="./config/nginx/certs"
mkdir -p "$NGINX_CERTS_DIR"

# Prompt for certificate type
echo -e "\n${BLUE}Certificate Options:${NC}"
echo "1) Self-signed certificates (for testing/development)"
echo "2) Let's Encrypt certificates (for production)"
read -p "Select an option [1]: " cert_option
cert_option=${cert_option:-1}

case $cert_option in
  1)
    generate_certificates "$DOMAIN" "$NGINX_CERTS_DIR" "self-signed"
    
    # Update .env file to use SSL
    sed -i 's/USE_SSL=false/USE_SSL=true/g' .env
    
    echo -e "\n${GREEN}Self-signed certificates generated successfully.${NC}"
    echo -e "${YELLOW}Important: Self-signed certificates will show security warnings in browsers.${NC}"
    echo -e "${YELLOW}           Use Let's Encrypt certificates for production environments.${NC}"
    ;;
    
  2)
    echo -e "\n${BLUE}Let's Encrypt Certificate Setup${NC}"
    echo -e "${YELLOW}To set up Let's Encrypt certificates, you'll need:${NC}"
    echo "1) A public domain name pointing to your server"
    echo "2) Port 80 open to the internet (for the ACME challenge)"
    
    read -p "Do you want to continue? (y/n) [y]: " continue_le
    continue_le=${continue_le:-y}
    
    if [[ $continue_le =~ ^[Yy]$ ]]; then
      echo -e "\n${YELLOW}Let's Encrypt Setup Instructions:${NC}"
      echo "1) Install certbot on your host system:"
      echo "   Ubuntu/Debian: sudo apt-get install certbot"
      echo "   CentOS/RHEL: sudo yum install certbot"
      
      echo -e "\n2) Obtain certificates for each subdomain:"
      echo "   certbot certonly --standalone -d gitea.${DOMAIN} -d drone.${DOMAIN} -d portainer.${DOMAIN} -d kasm.${DOMAIN}"
      
      echo -e "\n3) Copy the certificates to the Nginx certs directory:"
      echo "   sudo cp /etc/letsencrypt/live/gitea.${DOMAIN}/fullchain.pem ${NGINX_CERTS_DIR}/gitea.${DOMAIN}.crt"
      echo "   sudo cp /etc/letsencrypt/live/gitea.${DOMAIN}/privkey.pem ${NGINX_CERTS_DIR}/gitea.${DOMAIN}.key"
      echo "   (Repeat for each subdomain)"
      
      echo -e "\n4) Set up auto-renewal:"
      echo "   sudo certbot renew --dry-run"
      echo "   sudo crontab -e"
      echo "   Add: 0 3 * * * certbot renew --quiet && docker-compose restart nginx"
      
      echo -e "\n${YELLOW}Would you like to generate temporary self-signed certificates until you set up Let's Encrypt?${NC}"
      read -p "Generate temporary certificates? (y/n) [y]: " temp_certs
      temp_certs=${temp_certs:-y}
      
      if [[ $temp_certs =~ ^[Yy]$ ]]; then
        generate_certificates "$DOMAIN" "$NGINX_CERTS_DIR" "self-signed"
        
        # Update .env file to use SSL
        sed -i 's/USE_SSL=false/USE_SSL=true/g' .env
        
        echo -e "\n${GREEN}Temporary self-signed certificates generated.${NC}"
        echo -e "${YELLOW}Remember to replace these with Let's Encrypt certificates.${NC}"
      fi
    fi
    ;;
    
  *)
    echo -e "${RED}Invalid option. Exiting.${NC}"
    exit 1
    ;;
esac

# Next steps
echo -e "\n${BLUE}Next Steps:${NC}"
echo "1) Ensure your docker-compose.yml is configured for HTTPS"
echo "2) Restart the stack to apply SSL: docker-compose down && docker-compose up -d"
echo "3) Test HTTPS access to your services"

echo -e "\n${GREEN}SSL Certificate setup completed!${NC}"