#!/bin/bash
set -e  # 遇到错误立即退出

# 打印调试信息
echo "Starting Nezha Dashboard setup..."

# 下载并解压 Dashboard
if [ ! -f "dashboard-linux-amd64.zip" ]; then
  echo "Downloading Nezha Dashboard..."
  wget -q https://github.com/nezhahq/nezha/releases/latest/download/dashboard-linux-amd64.zip
fi
unzip -qo dashboard-linux-amd64.zip
rm -f dashboard-linux-amd64.zip

# 下载 Cloudflared
if [ ! -f "cloudflared-linux-amd64" ]; then
  echo "Downloading Cloudflared..."
  wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
fi

# 设置执行权限
chmod +x dashboard-linux-amd64 cloudflared-linux-amd64

# 启动 Dashboard 并等待
echo "Starting Nezha Dashboard..."
./dashboard-linux-amd64 &
DASHBOARD_PID=$!

# 等待 Dashboard 启动
sleep 5

# 检查 Dashboard 是否正在运行
if ! kill -0 $DASHBOARD_PID 2>/dev/null; then
  echo "Failed to start Nezha Dashboard"
  exit 1
fi

# 检查端口是否监听
if ! netstat -tuln | grep :8008; then
  echo "Dashboard not listening on port 8008"
  exit 1
fi

# 启动 Cloudflare Tunnel
echo "Starting Cloudflare Tunnel..."
AGO_AUTH=${AGO_AUTH:-'eyJhIjoiZjAzMGY1ZDg4OGEyYmRlN2NiMDg3NTU5MzM4ZjE0OTciLCJ0IjoiZjIzMDA3MWUtYjBhMy00ZGM0LTg2MjYtMDVjYjQzNmM3Y2YxIiwicyI6Ik0yTTRPVEl6TWpjdE1tWXdPQzAwTWpkaUxUazJNamN0Tkdaak9EaGlNakE0T1dKayJ9'}
./cloudflared-linux-amd64 tunnel --edge-ip-version auto --protocol http2 --no-autoupdate run --token "$AGO_AUTH" &

# 安装 Nezha Agent
echo "Installing Nezha Agent..."
curl -L https://raw.githubusercontent.com/nezhahq/scripts/main/agent/install.sh -o nezha.sh && \
chmod +x nezha.sh && \
env NZ_SERVER=adkynet.cx.dedyn.io:8008 NZ_TLS=false NZ_CLIENT_SECRET=cWQtULdgpboeUq6wwn8iEknyRpexDGlf ./nezha.sh

# 启动 Nginx
echo "Starting Nginx..."
nginx -g "daemon off;"
