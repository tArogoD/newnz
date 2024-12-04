FROM nginx:stable-debian
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    bash \
    curl \
    git \
    tar \
    openssl \
    python3 \
    python3-pip \
    certbot \
    python3-certbot-nginx \
    && rm -rf /var/lib/apt/lists/*

COPY start.sh backup.sh restore.sh /app/
WORKDIR /app
RUN chmod +x start.sh backup.sh restore.sh
EXPOSE 80 443
ENTRYPOINT ["/app/start.sh"]
