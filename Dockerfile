FROM nginx:stable-alpine

RUN apk add --no-cache wget unzip bash curl git tar

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY start.sh backup.sh restore.sh /app

RUN chmod +x /start.sh /backup.sh /restore.sh

EXPOSE 80

WORKDIR /app

ENTRYPOINT ["/start.sh"]
