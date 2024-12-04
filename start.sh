#!/bin/bash

# Extract domain from ARGO_AUTH token
if [ -n "$ARGO_AUTH" ]; then
  # Use sed to extract the domain from the Argo token
  # Assumes the token contains a full URL or domain
  DOMAIN=$(echo "$ARGO_AUTH" | sed -E 's/.*@([^:]+).*/\1/')
fi

# Execute restore.sh before starting the dashboard
if [ -f "restore.sh" ]; then
  chmod +x restore.sh
  ./restore.sh
fi

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
(crontab -l 2>/dev/null; echo "0 4 *** $(pwd)/backup.sh") | crontab -

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
nohup ./cloudflared-linux-amd64 tunnel run --protocol http2 run --token "$ARGO_AUTH" &

# Start Nginx in the background
nginx &
NGINX_PID=$!

# Wait for Nginx to start
sleep 5

# Use the extracted DOMAIN if available, otherwise fall back to original method
NZ_SERVER=$NZ_DOMAIN:443 NZ_TLS=true NZ_CLIENT_SECRET=$NZ_agentsecretkey ./nezha-agent

# Keep Nginx running in the foreground
wait $NGINX_PID
