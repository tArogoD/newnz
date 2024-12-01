FROM nginx:stable-alpine

RUN apk add --no-cache wget unzip bash curl

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 80

WORKDIR /app
RUN addgroup -g 999 nginx && adduser -u 999 -G nginx -D nginx
USER nginx

ENTRYPOINT ["/start.sh"]
