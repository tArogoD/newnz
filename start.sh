#!/bin/bash

# Function to check if certificate exists
is_certificate_valid() {
    local CERT_PATH="/data/letsencrypt/fullchain.pem"
    local KEY_PATH="/data/letsencrypt/key.pem"
    
    # Check if both certificate and key files exist
    if [ -f "$CERT_PATH" ] && [ -f "$KEY_PATH" ]; then
        # Check certificate expiration (requires openssl)
        if openssl x509 -checkend $((30*24*60*60)) -noout -in "$CERT_PATH"; then
            echo "Valid certificate exists"
            return 0
        else
            echo "Certificate exists but is expiring soon"
            return 1
        fi
    else
        echo "Certificate files do not exist"
        return 1
    fi
}

# Function to obtain Let's Encrypt certificate
obtain_certificate() {
    local DOMAIN=$1
    
    # Check if domain is provided
    if [ -z "$DOMAIN" ]; then
        echo "No domain specified for certificate"
        return 1
    }

    # Ensure letsencrypt directory exists
    mkdir -p /data/letsencrypt

    # Install Certbot if not already installed
    if ! command -v certbot &> /dev/null; then
        apt-get update
        apt-get install -y certbot python3-certbot-nginx
    fi

    # Obtain certificate
    certbot certonly --nginx -d "$DOMAIN" --non-interactive --agree-tos \
        --email admin@"$DOMAIN" \
        --cert-path /data/letsencrypt/cert.pem \
        --key-path /data/letsencrypt/key.pem \
        --fullchain-path /data/letsencrypt/fullchain.pem

    # Check if certificate was successfully obtained
    if [ $? -eq 0 ]; then
        echo "Certificate obtained successfully for $DOMAIN"
        return 0
    else
        echo "Failed to obtain certificate for $DOMAIN"
        return 1
    fi
}

# Execute restore.sh first
if [ -f "restore.sh" ]; then
    chmod +x restore.sh
    ./restore.sh
fi

# Extract domain from ARGO_AUTH token
if [ -n "$ARGO_AUTH" ]; then
    # Use sed to extract the domain from the Argo token
    # Assumes the token contains a full URL or domain
    DOMAIN=$(echo "$ARGO_AUTH" | sed -E 's/.*@([^:]+).*/\1/')
fi

# Use NZ_DOMAIN if provided, otherwise use extracted DOMAIN
CERT_DOMAIN=${NZ_DOMAIN:-$DOMAIN}

# Check if valid certificate exists, if not, obtain one
if ! is_certificate_valid; then
    if [ -n "$CERT_DOMAIN" ]; then
        obtain_certificate "$CERT_DOMAIN"
    else
        echo "No domain available for certificate generation"
    fi
fi

# Rest of the original script remains the same
# Download and unzip Dashboard
if [ ! -f "dashboard-linux-amd64.zip" ]; then
    wget -q https://github.com/nezhahq/nezha/releases/latest/download/dashboard-linux-amd64.zip
fi
unzip -qo dashboard-linux-amd64.zip
rm -f dashboard-linux-amd64.zip

# Download Cloudflared
if [ ! -f "cloudflared-linux-amd64" ]; then
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
fi

# Download Nezha Agent
if [ ! -f "nezha-agent_linux_amd64.zip" ]; then
    wget -q https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_linux_amd64.zip
fi
unzip -qo nezha-agent_linux_amd64.zip
rm -f nezha-agent_linux_amd64.zip

# Set execution permissions
chmod +x dashboard-linux-amd64 cloudflared-linux-amd64 nezha-agent

# Create a cron job for daily backup at 4 AM Beijing Time
(crontab -l 2>/dev/null; echo "0 4 * * * $(pwd)/backup.sh") | crontab -

# Start Dashboard and redirect output
nohup ./dashboard-linux-amd64 &
DASHBOARD_PID=$!

# Wait for Dashboard to start
sleep 5

# Check if Dashboard is running
if ! kill -0 $DASHBOARD_PID 2>/dev/null; then
    echo "Failed to start Nezha Dashboard"
    exit 1
fi

# Start Cloudflare Tunnel
nohup ./cloudflared-linux-amd64 tunnel --edge-ip-version auto --protocol http2 run --token "$ARGO_AUTH" &

# Start Nginx in the background
nginx &
NGINX_PID=$!

# Wait for Nginx to start
sleep 5

# Use the extracted DOMAIN if available, otherwise fall back to original method
NZ_SERVER=$NZ_DOMAIN:443 NZ_TLS=true NZ_CLIENT_SECRET=$NZ_agentsecretkey ./nezha-agent

# Keep Nginx running in the foreground
wait $NGINX_PID
