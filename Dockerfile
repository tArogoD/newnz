FROM nginx:stable-alpine
RUN apk add --no-cache \
    wget \
    unzip \
    bash \
    curl \
    git \
    tar \
    openssl \
    python3 \
    py3-pip \
    py3-setuptools

# 使用 pip 安装 certbot，并捕获可能的错误
RUN pip3 install --upgrade pip && \
    pip3 install --no-cache-dir certbot certbot-nginx || \
    (echo "Certbot installation failed" && exit 1)

COPY start.sh backup.sh restore.sh /app/
WORKDIR /app
RUN chmod +x start.sh backup.sh restore.sh
EXPOSE 80 443
ENTRYPOINT ["/app/start.sh"]
