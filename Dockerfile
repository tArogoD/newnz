FROM nginx:stable-alpine

RUN apk add --no-cache wget unzip bash curl git tar openssl python3 py3-pip

RUN wget https://bootstrap.pypa.io/get-pip.py && \
    python3 get-pip.py && \
    pip3 install certbot certbot-nginx
    
COPY start.sh backup.sh restore.sh /app/

WORKDIR /app

RUN chmod +x start.sh backup.sh restore.sh

EXPOSE 80 443

ENTRYPOINT ["/app/start.sh"]
