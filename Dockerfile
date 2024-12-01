FROM nginx:stable-alpine

RUN apk add --no-cache wget unzip bash curl

RUN addgroup -g 999 pinggroup && \
    adduser -u 999 -G pinggroup -D pinguser

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 80

WORKDIR /app

ENTRYPOINT ["/start.sh"]
