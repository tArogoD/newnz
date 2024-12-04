#!/bin/bash

# Execute restore script if exists as the FIRST step
if [ -f "restore.sh" ]; then
    chmod +x restore.sh
    ./restore.sh
fi

# Ensure required environment variables are set
[ -z "$NZ_DOMAIN" ] && { echo "NZ_DOMAIN is not set"; exit 1; }

# Create necessary directories
mkdir -p /data/letsencrypt /etc/nginx/conf.d

# Check certificate validity
is_certificate_valid() {
    local CERT_PATH="/data/letsencrypt/fullchain.pem"
    local KEY_PATH="/data/letsencrypt/key.pem"
    
    [ -f "$CERT_PATH" ] && [ -f "$KEY_PATH" ] && 
    openssl x509 -checkend $((30*24*60*60)) -noout -in "$CERT_PATH" && 
    return 0
    
    return 1
}

# Generate Nginx configuration
generate_nginx_config() {
    cat > /etc/nginx/conf.d/default.conf << EOL
server {
    http2 on;
    server_name $NZ_DOMAIN;
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    ssl_certificate          /data/letsencrypt/fullchain.pem;
    ssl_certificate_key      /data/letsencrypt/key.pem;
    ssl_stapling on;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    underscores_in_headers on;
    set_real_ip_from 0.0.0.0/0; 
    real_ip_header CF-Connecting-IP; 

    location ^~ /proto.NezhaService/ {
        grpc_set_header Host \$host;
        grpc_set_header nz-realip \$http_CF_Connecting_IP;
        grpc_send_timeout 600s;
        grpc_socket_keepalive on;
        client_max_body_size 10m;
        grpc_buffer_size 4m;
        grpc_pass grpc://dashboard;
    }

    location ~* ^/api/v1/ws/(server|terminal|file)(.*)$ {
        proxy_set_header Host \$host;
        proxy_set_header nz-realip \$http_cf_connecting_ip;
        proxy_set_header Origin https://\$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_pass http://dashboard;
    }

    location / {
        proxy_set_header Host \$host;
        proxy_set_header nz-realip \$http_cf_connecting_ip;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
        proxy_max_temp_file_size 0;
        proxy_pass http://dashboard;
    }
}

upstream dashboard {
    server localhost:8008;
    keepalive 512;
}
EOL

    nginx -t && return 0
}

# Obtain Let's Encrypt certificate
obtain_certificate() {
    # Install Certbot if not already installed
    command -v certbot &> /dev/null || {
        apt-get update
        apt-get install -y certbot python3-certbot-nginx
    }

    # Obtain certificate
    certbot certonly --nginx -d "$NZ_DOMAIN" --non-interactive --agree-tos \
        --email admin@"$NZ_DOMAIN" \
        --cert-path /data/letsencrypt/cert.pem \
        --key-path /data/letsencrypt/key.pem \
        --fullchain-path /data/letsencrypt/fullchain.pem
}

# Obtain certificate and generate config if needed
is_certificate_valid || {
    obtain_certificate
    generate_nginx_config
}

# Download and prepare components
wget -qO dashboard-linux-amd64.zip https://github.com/nezhahq/nezha/releases/latest/download/dashboard-linux-amd64.zip
unzip -qo dashboard-linux-amd64.zip && rm dashboard-linux-amd64.zip

wget -qO cloudflared-linux-amd64 https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64

wget -qO nezha-agent_linux_amd64.zip https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_linux_amd64.zip
unzip -qo nezha-agent_linux_amd64.zip && rm nezha-agent_linux_amd64.zip

# Set execution permissions
chmod +x dashboard-linux-amd64 cloudflared-linux-amd64 nezha-agent

# Create backup cron job
(crontab -l 2>/dev/null; echo "0 4 * * * $(pwd)/backup.sh") | crontab -

# Start components
nohup ./dashboard-linux-amd64 &
DASHBOARD_PID=$!

sleep 5

# Check Dashboard status
kill -0 $DASHBOARD_PID || {
    echo "Failed to start Nezha Dashboard"
    exit 1
}

nohup ./cloudflared-linux-amd64 tunnel --edge-ip-version auto --protocol http2 run --token "$ARGO_AUTH" &

nginx &
NGINX_PID=$!

sleep 5

# Start Nezha Agent
NZ_SERVER=$NZ_DOMAIN:443 NZ_TLS=true NZ_CLIENT_SECRET=$NZ_agentsecretkey ./nezha-agent

# Keep Nginx running
wait $NGINX_PID
