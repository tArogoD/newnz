FROM nginx:stable-alpine

RUN apk add --no-cache wget unzip bash curl

RUN useradd --no-log-init --create-home --user-group --uid 1000 ngnix

USER 1000:1000

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 80

WORKDIR /app

ENTRYPOINT ["/start.sh"]
