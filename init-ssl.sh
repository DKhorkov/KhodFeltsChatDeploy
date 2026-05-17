#!/bin/bash
# Скрипт первоначального получения SSL-сертификата.

set -e

DOMAIN="kfc.webtm.ru"
EMAIL="${1:?Укажите email: bash init-ssl.sh your@email.com}"

# Создаём директории для certbot
mkdir -p certbot/conf certbot/www

# Временный nginx-конфиг только с HTTP
cat > nginx-init.conf <<'EOF'
server {
    listen 80;
    server_name kfc.webtm.ru;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 200 'waiting for certificate...';
        add_header Content-Type text/plain;
    }
}
EOF

echo "==> Запускаем временный nginx для получения сертификата..."
sudo docker run -d --name nginx-init \
    --network kfc_network \
    -v "$(pwd)/nginx-init.conf:/etc/nginx/conf.d/default.conf" \
    -v "$(pwd)/certbot/www:/var/www/certbot" \
    -p 80:80 \
    nginx:alpine

echo "==> Получаем сертификат Let's Encrypt..."
sudo docker run --rm \
    --network kfc_network \
    -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
    -v "$(pwd)/certbot/www:/var/www/certbot" \
    certbot/certbot certonly \
    --webroot -w /var/www/certbot \
    -d "$DOMAIN" \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email

echo "==> Останавливаем временный nginx..."
sudo docker stop nginx-init && sudo docker rm nginx-init
rm -f nginx-init.conf

echo "==> SSL-сертификат получен! Запускайте: task -d scripts up -v"
