FROM nginx:stable-alpine

RUN apk add --no-cache wget unzip bash curl git tar

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 80

WORKDIR /app

ENTRYPOINT ["/start.sh"]
