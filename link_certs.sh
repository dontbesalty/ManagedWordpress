#!/bin/bash

# Define variables
USERNAME=$1
APPNAME=$2
DOMAIN=$3

if [ -z "$USERNAME" ] || [ -z "$APPNAME" ] || [ -z "$DOMAIN" ]; then
  echo "Usage: $0 USERNAME APPNAME DOMAIN"
  exit 1
fi

SSL_PATH="/srv/$USERNAME/apps/$APPNAME/ssl"

# Create SSL directory
mkdir -p $SSL_PATH

# Create symlinks
ln -sf /etc/letsencrypt/live/$DOMAIN/fullchain.pem $SSL_PATH/$DOMAIN.crt
ln -sf /etc/letsencrypt/live/$DOMAIN/privkey.pem $SSL_PATH/$DOMAIN.key

# Update Nginx config
NGINX_CONFIG="/etc/nginx/sites-available/$APPNAME.conf"

if [ ! -f "$NGINX_CONFIG" ]; then
  echo "Nginx config file not found: $NGINX_CONFIG"
  exit 1
fi

# Replace the ssl_certificate and ssl_certificate_key lines
sed -i "s|ssl_certificate /etc/nginx/ssl/.*.crt;|ssl_certificate $SSL_PATH/$DOMAIN.crt;|g" $NGINX_CONFIG
sed -i "s|ssl_certificate_key /etc/nginx/ssl/.*.key;|ssl_certificate_key $SSL_PATH/$DOMAIN.key;|g" $NGINX_CONFIG

# Test Nginx config
nginx -t

# Reload Nginx
systemctl reload nginx

# Update user.json
APPDATA_FILE=/var/lib/appdata/users.json
sudo jq ".\"users\".\"$USERNAME\".\"apps\".\"$APPNAME\" += {\"ssl\": true}" "$APPDATA_FILE" > /tmp/tmp.json && sudo mv /tmp/tmp.json "$APPDATA_FILE"

echo "SSL certificates linked and Nginx config updated for $DOMAIN"
