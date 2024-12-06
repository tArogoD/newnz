#!/bin/bash

WORK_DIR=/app
REPOS=(
    "nezhahq/nezha:dashboard-linux-amd64.zip:dashboard"
    "nezhahq/agent:nezha-agent_linux_amd64.zip:agent"
)

# 获取最新版本
get_latest_version() {
    local repo="$1"
    curl -s "https://api.github.com/repos/$repo/releases/latest" | sed -n 's/.*"tag_name": *"\(v\?\([^"]*\)\)".*/\2/p'
}

# 下载并解压组件
download_component() {
    local repo="$1" filename="$2" component="$3"
    local latest_version=$(get_latest_version "$repo")
    local download_url="https://github.com/$repo/releases/latest/download/$filename"

    wget -q "$download_url" -O "$filename"
    if [ -f "$filename" ]; then
        unzip -qo "$filename" -d "$WORK_DIR" && rm "$filename"
        return 0
    else
        return 1
    fi
}

# 检查并更新组件
update_component() {
    local repo="$1" filename="$2" component="$3"
    local latest_version=$(get_latest_version "$repo")
    local current_version=""
    local version_number=""

    # 检查组件是否存在
    if [ ! -f "./${component}-linux-amd64" ]; then
        # 文件不存在，首次运行直接下载
        download_component "$repo" "$filename" "$component" || {
            return 1
        }
        return 0
    fi

    # 获取当前版本
    if [ "$component" == "dashboard" ]; then
        current_version=$(./dashboard-linux-amd64 -v 2>/dev/null)
    elif [ "$component" == "agent" ]; then
        current_version=$(./nezha-agent -v 2>/dev/null | awk '{print $3}')
    fi

    # 提取纯数字版本号(移除所有非数字和点号字符)
    latest_version_number=$(echo "$latest_version" | sed 's/[^0-9.]//g')
    current_version_number=$(echo "$current_version" | sed 's/[^0-9.]//g')

    # 比较版本并决定是否更新
    if [ "$current_version_number" != "$latest_version_number" ]; then
        download_component "$repo" "$filename" "$component" || {
            return 1
        }
        return 0  # 成功更新
    else
        return 1  # 未更新
    fi
}

# 设置 SSL
setup_ssl() {
    openssl genrsa -out $WORK_DIR/nezha.key 2048
    openssl req -new -key $WORK_DIR/nezha.key -out $WORK_DIR/nezha.csr -subj "/CN=$NZ_DOMAIN"
    openssl x509 -req -days 3650 -in $WORK_DIR/nezha.csr -signkey $WORK_DIR/nezha.key -out $WORK_DIR/nezha.pem
    chmod 600 $WORK_DIR/nezha.key
    chmod 644 $WORK_DIR/nezha.pem
}

# 启动服务
start_services() {
    # 启动 Nginx
    nginx &
    sleep 2
    
    # 启动 Cloudflared
    nohup ./cloudflared-linux-amd64 tunnel --protocol http2 run --token "$ARGO_AUTH" >/dev/null 2>&1 &
    sleep 2
    
    # 启动仪表板
    nohup ./dashboard-linux-amd64 >/dev/null 2>&1 &
    sleep 5
    
    # 启动 Nezha Agent
    NZ_SERVER=$NZ_DOMAIN:443 NZ_TLS=true NZ_CLIENT_SECRET=$NZ_agentsecretkey nohup ./nezha-agent >/dev/null 2>&1 &
}

# 停止服务
stop_services() {
    pkill -f "dashboard-linux-amd64|cloudflared-linux-amd64|nezha-agent|nginx"
}

main() {
    # 检查必要的环境变量
    [ -z "$NZ_DOMAIN" ] && { echo "Error: NZ_DOMAIN not set"; exit 1; }
    [ -z "$ARGO_AUTH" ] && { echo "Error: ARGO_AUTH not set"; exit 1; }
    [ -z "$NZ_agentsecretkey" ] && { echo "Error: NZ_agentsecretkey not set"; exit 1; }

    # 恢复
    [ -f "restore.sh" ] && { chmod +x restore.sh; ./restore.sh; }

    # 设置 SSL
    setup_ssl

    # 更新组件
    for repo_info in "${REPOS[@]}"; do
        IFS=: read -r repo filename component <<< "$repo_info"
        update_component "$repo" "$filename" "$component" || true
    done

    # 下载 Cloudflared
    [ ! -f "cloudflared-linux-amd64" ] && wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64

    # 设置权限
    chmod +x dashboard-linux-amd64 cloudflared-linux-amd64 nezha-agent

    # 创建 Nginx 配置
    cat << EOF > /etc/nginx/conf.d/default.conf
server {
    listen 80;
    listen [::]:80;
    http2 on;

    server_name $NZ_DOMAIN;
    ssl_certificate          $WORK_DIR/nezha.pem;
    ssl_certificate_key      $WORK_DIR/nezha.key;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;

    underscores_in_headers on;
    set_real_ip_from 0.0.0.0/0;
    real_ip_header CF-Connecting-IP;

    location ^~ /proto.NezhaService/ {
        grpc_set_header Host \$host;
        grpc_set_header nz-realip \$http_CF_Connecting_IP;
        grpc_read_timeout 600s;
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
EOF

    # 启动服务
    start_services
}

# 主循环
while true; do
    # 执行主程序
    main

    # 等待 30 分钟
    sleep 1800

    # 检查更新
    updated=0
    for repo_info in "${REPOS[@]}"; do
        IFS=: read -r repo filename component <<< "$repo_info"
        if update_component "$repo" "$filename" "$component"; then
            updated=1
        fi
    done

    # 如果有组件更新，则重启服务
    if [ $updated -eq 1 ]; then
        stop_services
        "$0" &  # 使用后台方式运行脚本
        exit 0  # 退出当前进程"
    fi
done
