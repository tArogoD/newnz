#!/bin/bash
AGO_AUTH=${AGO_AUTH:-'eyJhIjoiZjAzMGY1ZDg4OGEyYmRlN2NiMDg3NTU5MzM4ZjE0OTciLCJ0IjoiZjIzMDA3MWUtYjBhMy00ZGM0LTg2MjYtMDVjYjQzNmM3Y2YxIiwicyI6Ik0yTTRPVEl6TWpjdE1tWXdPQzAwTWpkaUxUazJNamN0Tkdaak9EaGlNakE0T1dKayJ9'}
if [ ! -f "dashboard-linux-amd64.zip" ]; then
  wget -q https://github.com/nezhahq/nezha/releases/latest/download/dashboard-linux-amd64.zip
fi
unzip -qo dashboard-linux-amd64.zip
rm -f dashboard-linux-amd64.zip
if [ ! -f "cloudflared-linux-amd64" ]; then
  wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
fi
chmod +x dashboard-linux-amd64 cloudflared-linux-amd64
nohup ./dashboard-linux-amd64 >/dev/null 2>&1 &
nohup ./cloudflared-linux-amd64 tunnel --edge-ip-version auto --protocol http2 --no-autoupdate run --token "$AGO_AUTH" >/dev/null 2>&1 &

nginx -g "daemon off;"
