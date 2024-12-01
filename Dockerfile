FROM nginx:stable-alpine

RUN apk add --no-cache wget unzip bash curl

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 80

WORKDIR /app

RUN echo "0 65535" > /proc/sys/net/ipv4/ping_group_range

ENTRYPOINT ["/start.sh"]
