# Healthchecks.io Docker Compose Setup

This project provides a complete Docker Compose setup for running [Healthchecks.io](https://healthchecks.io/) with PostgreSQL database backend and Tailscale integration for secure remote access.

## Overview

The setup includes:
- **Healthchecks.io**: The main application for monitoring cron jobs and scheduled tasks
- **PostgreSQL**: Database backend for persistent data storage
- **Tailscale**: Secure VPN access to the application
- **Sendalerts**: Background service for sending notifications

The application is accessible via Tailscale's secure network, eliminating the need for port forwarding or exposing services to the public internet.

## Prerequisites

- A fresh Ubuntu system (22.04 LTS or newer recommended)
- Tailscale account and auth key
- SSH access to the server

## Initial Server Setup

### 1. Create Ubuntu User with Sudo Rights

First, log in as root and create a new ubuntu user:

```bash
# Create the ubuntu user
adduser ubuntu

# Add ubuntu user to sudo group
usermod -aG sudo ubuntu

# Verify sudo access
sudo -l -U ubuntu
```

### 2. Disable Root Password and SSH Login

Edit the SSH configuration:

```bash
# Edit SSH config
nano /etc/ssh/sshd_config
```

Make the following changes:
```
PermitRootLogin no
PasswordAuthentication no
```

Restart SSH service:
```bash
systemctl restart ssh
```

### 3. Copy SSH Public Key to Ubuntu User

While still logged in as root, copy the SSH keys:

```bash
# Create .ssh directory for ubuntu user
mkdir -p /home/ubuntu/.ssh

# Copy authorized_keys from root to ubuntu user
cp /root/.ssh/authorized_keys /home/ubuntu/.ssh/

# Set proper ownership and permissions
chown -R ubuntu:ubuntu /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh
chmod 600 /home/ubuntu/.ssh/authorized_keys
```

### 4. Install Docker

Log out and log back in as the ubuntu user, then install Docker:

```bash
# Update package index
sudo apt update

# Install required packages
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index again
sudo apt update

# Install Docker Engine
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add ubuntu user to docker group
sudo usermod -aG docker ubuntu

# Log out and log back in for group changes to take effect
exit
```

After logging back in, verify Docker installation:
```bash
docker --version
docker compose version
```

## Project Setup

### 1. Clone the Repository

```bash
# Clone the repository
git clone https://github.com/QNimbus/home-ops-healthchecks.git
cd home-ops-healthchecks
```

### 2. Create Environment File

Create a `.env` file based on the provided example:

```bash
cp .env.example .env
nano .env
```

**Required Variables to Configure:**

At minimum, you must configure these variables in your `.env` file:

```bash
# Tailscale Configuration
TS_AUTHKEY=your_tailscale_auth_key_here
# Note: TS_CERT_DOMAIN is automatically replaced by Tailscale - no manual configuration needed

# Update the hostname in ALLOWED_HOSTS
ALLOWED_HOSTS=healthchecks.your-tailnet.ts.net,localhost,127.0.0.1

# Database Configuration (update the password)
DB_PASSWORD=your_secure_database_password_here

# Generate a secure Django secret key
SECRET_KEY=your_django_secret_key_here

# Email Configuration (required for notifications)
DEFAULT_FROM_EMAIL=healthchecks@yourdomain.com
EMAIL_HOST=smtp.gmail.com
EMAIL_HOST_USER=your_email@gmail.com
EMAIL_HOST_PASSWORD=your_app_password

# Site Configuration
SITE_ROOT=https://healthchecks.your-tailnet.ts.net
SITE_NAME=Your Healthchecks Instance
```

**Important Notes:**
- Get your Tailscale auth key from: https://login.tailscale.com/admin/settings/keys
- Generate a Django secret key using: `openssl rand -base64 32`
- Replace `healthchecks.your-tailnet.ts.net` with your actual Tailscale domain
- For Gmail, use an App Password instead of your regular password
- The `TS_CERT_DOMAIN` variable in `config/serve-config.json` is automatically replaced by Tailscale with your actual domain

### Important: CSRF Protection Configuration

The `.env.example` file includes this important setting:
```bash
SECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO,https
```

**Why is this needed?**

When using Tailscale Serve (or any reverse proxy) with HTTPS, Django needs to know that the original request was secure (HTTPS) even though the request to the backend application is HTTP. Without this setting, you may encounter CSRF (Cross-Site Request Forgery) errors when trying to log in or perform other actions.

**The Problem:**
- Tailscale Serve terminates HTTPS and forwards HTTP requests to the Healthchecks container
- Django sees the request as HTTP (insecure) internally
- When Django performs CSRF validation, it compares the `Origin` header (which shows `https://your-domain.ts.net`) with the reconstructed URL based on the `Host` header and request security status
- Since Django thinks the request is HTTP, it reconstructs `http://your-domain.ts.net` but the Origin header shows `https://your-domain.ts.net`
- This mismatch causes CSRF validation to fail

**The Solution:**
The `SECURE_PROXY_SSL_HEADER` setting tells Django to trust the `X-Forwarded-Proto` header when determining if a request was secure. Tailscale Serve automatically adds this header when forwarding HTTPS requests.

For more details, see the [Django documentation](https://docs.djangoproject.com/en/5.1/ref/settings/#std-setting-SECURE_PROXY_SSL_HEADER) and [GitHub discussion #851](https://github.com/healthchecks/healthchecks/discussions/851).

### 3. Start the Services

Pull the latest images and start the services:

```bash
# Pull all container images
docker compose pull

# Start all services in the background
docker compose up -d
```

### 4. Initialize the Database

Run the database migrations:

```bash
# Run database migrations
docker compose exec healthchecks python manage.py migrate
```

### 5. Create Admin User

Create a superuser account for accessing the admin interface:

```bash
# Create superuser (you'll be prompted for email and password)
docker compose exec healthchecks python manage.py createsuperuser
```

## Accessing the Application

Once everything is set up:

1. Ensure your client device is connected to the same Tailscale network
2. Access the application at: `https://healthchecks.your-tailnet.ts.net` (replace with your actual domain)
3. Log in with the superuser credentials you created

**Note**: The application uses Tailscale Serve to provide HTTPS access. The configuration in `config/serve-config.json` automatically sets up HTTPS termination and proxies requests to the Healthchecks application running on port 8000.

### Optional: Public Internet Access with Tailscale Funnel

By default, this setup only allows access from devices connected to your Tailscale network. If you want to expose your Healthchecks instance to the public internet, you can enable Tailscale Funnel:

**1. Update the serve configuration:**

Edit `config/serve-config.json` and change the `AllowFunnel` setting from `false` to `true`:

```json
{
  "TCP": {
    "443": { "HTTPS": true }
  },
  "Web": {
    "${TS_CERT_DOMAIN}:443": {
      "Handlers": {
        "/": {
          "Proxy": "http://127.0.0.1:8000"
        }
      }
    }
  },
  "AllowFunnel": {
    "${TS_CERT_DOMAIN}:443": true
  }
}
```

**2. Configure Tailscale ACL:**

You must also update your Tailscale Access Control List (ACL) to allow funnel access for the healthchecks service. Add the following to your ACL policy at https://login.tailscale.com/admin/acls:

```json
{
  "nodeAttrs": [
    {
      "target": ["tag:healthchecks"],
      "attr": ["funnel"]
    }
  ]
}
```

**3. Restart the services:**

After making these changes, restart the Tailscale container:

```bash
docker compose restart tailscale
```

**Important Security Considerations:**
- ⚠️ **This exposes your Healthchecks instance to the entire internet**
- Consider disabling user registration: Set `REGISTRATION_OPEN=False` in your `.env` file
- Use strong passwords and consider enabling two-factor authentication if supported
- Regularly monitor access logs and update your instance
- Only enable this if you specifically need public internet access

Your Healthchecks instance will then be accessible at `https://your-tailscale-domain.ts.net` from anywhere on the internet, not just from devices on your Tailscale network.

## Service Management

### Check Service Status
```bash
# View running containers
docker compose ps

# View logs
docker compose logs -f healthchecks
docker compose logs -f postgres
docker compose logs -f tailscale
```

### Start/Stop Services
```bash
# Stop all services
docker compose down

# Start all services
docker compose up -d

# Restart specific service
docker compose restart healthchecks
```

### Update Services
```bash
# Pull latest images
docker compose pull

# Recreate containers with new images
docker compose up -d
```

## Backup and Maintenance

### Database Backup
```bash
# Create database backup
docker compose exec postgres pg_dump -U healthchecks healthchecks > backup_$(date +%Y%m%d_%H%M%S).sql
```

### Database Restore
```bash
# Restore from backup
docker compose exec -T postgres psql -U healthchecks healthchecks < backup_file.sql
```

### View Application Logs
```bash
# View real-time logs
docker compose logs -f healthchecks

# View specific number of log lines
docker compose logs --tail=100 healthchecks
```

## Troubleshooting

### Common Issues

1. **Services won't start**: Check logs with `docker compose logs`
2. **Database connection errors**: Ensure PostgreSQL is fully started before healthchecks
3. **Tailscale authentication**: Verify your auth key is correct and has not expired
4. **Permission issues**: Ensure the ubuntu user is in the docker group

### Reset Everything
```bash
# Stop and remove all containers, networks, and volumes
docker compose down -v

# Remove all images
docker compose down --rmi all

# Start fresh
docker compose up -d
```

## Security Considerations

- The application is only accessible via Tailscale network
- No ports are exposed to the public internet
- Database is isolated within the Docker network
- Regular security updates should be applied to the host system

## Support

For issues related to:
- **Healthchecks.io**: Visit the [official documentation](https://healthchecks.io/docs/)
- **Docker**: Check the [Docker documentation](https://docs.docker.com/)
- **Tailscale**: See the [Tailscale documentation](https://tailscale.com/kb/)