FROM nginx:stable-alpine

RUN apk add --no-cache wget unzip bash curl

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 80

WORKDIR /app

RUN groupadd -g 999 appgroup
RUN useradd -u 999 -g appgroup appuser

ENTRYPOINT ["/start.sh"]
