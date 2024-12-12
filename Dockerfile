FROM nginx:alpine

RUN apk add --no-cache wget unzip bash curl git tar openssl jq procps

COPY start.sh backup.sh restore.sh /app/

WORKDIR /app

RUN chmod +x start.sh backup.sh restore.sh

EXPOSE 80 443

ENTRYPOINT ["/app/start.sh"]
