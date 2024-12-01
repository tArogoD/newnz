#!/bin/bash

# 下载并解压 Dashboard
if [ ! -f "dashboard-linux-amd64.zip" ]; then
  wget -q https://github.com/nezhahq/nezha/releases/latest/download/dashboard-linux-amd64.zip
fi
unzip -qo dashboard-linux-amd64.zip
rm -f dashboard-linux-amd64.zip

# 下载 Cloudflared
if [ ! -f "cloudflared-linux-amd64" ]; then
  wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
fi

# 下载 Nezha Agent
if [ ! -f "nezha-agent_linux_amd64.zip" ]; then
  wget -q https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_linux_amd64.zip
fi
unzip -qo nezha-agent_linux_amd64.zip
rm -f nezha-agent_linux_amd64.zip

# 设置执行权限
chmod +x dashboard-linux-amd64 cloudflared-linux-amd64 nezha-agent

# 启动 Dashboard 并重定向输出
nohup ./dashboard-linux-amd64 &
DASHBOARD_PID=$!

# 等待 Dashboard 启动
sleep 5

# 检查 Dashboard 是否正在运行
if ! kill -0 $DASHBOARD_PID 2>/dev/null; then
  echo "Failed to start Nezha Dashboard"
  exit 1
fi

# 启动 Cloudflare Tunnel
nohup ./cloudflared-linux-amd64 tunnel --edge-ip-version auto --protocol http2 run --token "$ARGO_AUTH" &

# 启动 Nezha Agent
NZ_SERVER=127.0.0.1:8008 NZ_TLS=false NZ_CLIENT_SECRET=$NZ_agentsecretkey nohup ./nezha-agent &

# 启动 Nginx 并保持前台运行
nginx -g "daemon off;"
