# DevOps Stack Setup and Usage Guide

This comprehensive guide will walk you through setting up and using the integrated DevOps stack with Gitea, Drone CI/CD, Portainer, and Kasm Workspaces.

## Overview

The DevOps stack provides a complete environment for software development, version control, continuous integration, deployment, and management. The key components are:

- **Gitea**: Self-hosted Git service for source code management
- **Drone CI/CD**: Continuous integration and delivery platform
- **Portainer**: Container management interface
- **Kasm Workspaces**: Browser-based containerized desktops/applications (including Postman)
- **Nginx**: Reverse proxy for unified access to all services

## Prerequisites

- Linux server with Docker and Docker Compose installed
- Git installed
- Sudo/root privileges
- At least 4GB RAM and 20GB disk space available
- Open ports: 80, 443 (for Nginx), 222 (for Gitea SSH)

## Initial Setup

1. **Clone or create the project directory**

   ```bash
   mkdir -p ~/devops-stack
   cd ~/devops-stack
   ```

2. **Create the directory structure**

   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

3. **Customize the .env file**

   Edit the `.env` file to set:
   - Domain settings
   - Admin usernames and passwords
   - Secret keys

4. **Start the services**

   ```bash
   docker-compose up -d
   ```

5. **Retrieve the Kasm API key**

   ```bash
   docker logs kasm_manager | grep "API KEY"
   ```

6. **Update the .env file with the Kasm API key**

   Edit the `.env` file to add the API key, then restart:
   ```bash
   docker-compose restart kasm_agent
   ```

## Configuration Steps

### 1. Gitea Setup

1. Access Gitea at `http://<your-server-ip>:3000` or `http://gitea.<your-domain>`
2. The first user to register becomes the admin or use the credentials in `.env`
3. Create a new OAuth2 Application:
   - Go to Settings > Applications
   - Create a new OAuth2 application named "Drone"
   - Set Redirect URI to `http://drone.<your-domain>/login`
   - Copy the generated Client ID and Secret

### 2. Drone CI/CD Setup

1. Update your `.env` file with the Gitea OAuth2 credentials:
   ```
   DRONE_GITEA_CLIENT_ID=your-client-id
   DRONE_GITEA_CLIENT_SECRET=your-client-secret
   ```

2. Restart Drone:
   ```bash
   docker-compose restart drone-server
   ```

3. Access Drone at `http://drone.<your-domain>` and authorize with your Gitea account

### 3. Portainer Setup

1. Access Portainer at `http://portainer.<your-domain>`
2. Create an admin user with a secure password
3. Connect to the local Docker environment

### 4. Kasm Workspaces Setup

1. Access Kasm at `https://kasm.<your-domain>:8443`
2. Log in with the admin credentials from `.env`
3. Add Workspaces as needed

## Usage Guide

### Using Gitea for Source Control

1. Create new repositories via the web interface
2. Clone repositories using HTTPS or SSH:
   ```bash
   # HTTPS
   git clone http://gitea.<your-domain>/<username>/<repo>.git
   
   # SSH
   git clone ssh://git@<your-server-ip>:222/<username>/<repo>.git
   ```

### Setting Up CI/CD with Drone

1. Activate repositories in Drone's UI
2. Add a `.drone.yml` file to your repository:

   ```yaml
   kind: pipeline
   type: docker
   name: default

   steps:
   - name: build
     image: node:14
     commands:
     - npm install
     - npm test
   ```

3. Commits to the repository will trigger builds

### Managing Containers with Portainer

1. Use Portainer to monitor all running containers
2. Deploy new stacks using the Stacks feature
3. Manage container resources and configurations

### Using Kasm Workspaces

1. Access the Postman workspace through Kasm
2. Use the custom DevOps environment for development tasks
3. Create and manage sessions through the Kasm interface

## Backup and Maintenance

### Creating Backups

Use the provided backup script:
```bash
./scripts/backup.sh
```

This will create a timestamped backup in the `backups` directory.

### Restoring from Backup

Use the provided restore script:
```bash
./scripts/restore.sh ./backups/20230101_120000
```

### Updating Containers

Keep your containers up to date:
```bash
./scripts/update.sh
```

### Monitoring Resources

Monitor container status and resource usage:
```bash
./scripts/monitor.sh
```

## Troubleshooting

### Common Issues

1. **Services not accessible**
   - Check if containers are running: `docker-compose ps`
   - Verify Nginx configuration: `docker logs nginx`
   - Check firewall settings

2. **Drone not connecting to Gitea**
   - Verify OAuth2 credentials in `.env`
   - Check Gitea and Drone logs

3. **Kasm agent not connecting**
   - Verify API key in `.env`
   - Check Kasm manager and agent logs

### Viewing Logs

View logs of specific containers:
```bash
docker-compose logs <service-name>
```

For continuous monitoring:
```bash
docker-compose logs -f <service-name>
```

## Customization

### Adding Custom Kasm Workspaces

1. Create a new Dockerfile in `custom/kasm-custom/`
2. Build and tag the image
3. Add the image to Kasm Workspaces through the admin interface

### Extending the Webhook Handler

Modify `custom/integrations/src/main.go` to add custom webhook handling logic for your specific needs.

## Security Considerations

1. Change all default passwords
2. Enable HTTPS using Let's Encrypt certificates
3. Restrict access to the services using network policies
4. Regularly update all containers
5. Back up your data frequently

## Advanced Configuration

### Setting Up HTTPS

1. Obtain SSL certificates (using Let's Encrypt or a commercial provider)
2. Update Nginx configuration with SSL certificates
3. Set `USE_SSL=true` in the `.env` file

### Custom Domain Configuration

Update the `.env` file with your custom domain and subdomains.

## Integration Examples

### GitHub Migration to Gitea

```bash
# Export GitHub repositories
gh repo list --json name,url -q '.[] | .name + "," + .url' > repos.csv

# Import to Gitea
while IFS=, read -r name url; do
  git clone --mirror "$url" "$name"
  cd "$name"
  git push --mirror http://gitea.<your-domain>/<username>/$name
  cd ..
  rm -rf "$name"
done < repos.csv
```

### Setting Up Webhook Integration

1. Configure webhook in Gitea repository:
   - URL: `http://webhook_handler:8000/webhook`
   - Secret: Use the value from `WEBHOOK_SECRET` in `.env`
   - Events: Push, Pull Request

2. The webhook handler will process these events according to the logic in `main.go`