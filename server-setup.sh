#!/bin/bash
# server-setup.sh
# Installs and configures Nginx, Apache, MariaDB, Redis, UFW, and ModSecurity on Ubuntu 24.04 LTS

# Exit immediately if a command exits with a non-zero status.
set -e

# Update package lists
apt update

# Install essential packages
apt install -y nginx apache2 mariadb-server redis-server ufw certbot python3-certbot-nginx php8.3 php8.3-fpm php8.3-mysql php8.3-redis php8.3-gd php8.3-curl php8.3-mbstring php8.3-xml

# Configure Nginx
# Set worker processes
sed -i 's/worker_processes  auto;/worker_processes 4;/' /etc/nginx/nginx.conf

# Enable gzip compression
sed -i '$i\
gzip on;\
gzip_vary on;\
gzip_proxied any;\
gzip_comp_level 6;\
gzip_buffers 16 8k;\
gzip_http_version 1.1;\
gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/rss+xml application/atom+xml image/svg+xml;\
' /etc/nginx/nginx.conf

# Configure FastCGI cache
echo "
fastcgi_cache_path /var/run/nginx-cache levels=1:2 keys_zone=WORDPRESS:100m inactive=60m;
fastcgi_cache_key \"\$scheme\$request_method\$host\$request_uri\";
fastcgi_cache_use_stale error timeout invalid_header http_500 http_502 http_503 http_504;
" >> /etc/nginx/nginx.conf

# Configure Apache
# Install mod_mpm_event and disable mod_mpm_prefork
apt install -y php8.3-fpm libapache2-mod-fastcgi
a2dismod mpm_prefork
a2enmod mpm_event
a2enmod actions fastcgi alias proxy_fcgi setenvif

# Configure PHP-FPM
sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/8.3/fpm/php.ini

# Configure MariaDB
# Secure MariaDB installation
mysql_secure_installation

# Configure Redis
# No changes needed for basic Redis configuration

# Configure UFW
read -r -p "Enable and configure UFW firewall? (y/N) " ufw_enable
if [[ "$ufw_enable" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
  ufw allow OpenSSH
  ufw allow 'Nginx Full'
  ufw enable
fi

# Install ModSecurity and OWASP Core Rule Set
apt install -y libapache2-mod-security2

# Download OWASP Core Rule Set
cd /tmp
wget https://github.com/coreruleset/coreruleset/archive/refs/tags/v4.0.0.tar.gz
tar -xvzf v4.0.0.tar.gz
mv coreruleset-4.0.0 /etc/modsecurity/crs

# Configure ModSecurity
cp /etc/modsecurity/crs/crs-setup.conf.example /etc/modsecurity/crs/crs-setup.conf

# Enable ModSecurity and OWASP CRS in Apache
echo "IncludeOptional /etc/modsecurity/crs/*.conf" >> /etc/apache2/mods-enabled/security2.conf

# Set paranoia level (optional)
sed -i 's/SecAction "id:900000, phase:1,nolog, pass, t:none, setvar:tx.paranoia_level=1"/SecAction "id:900000, phase:1,nolog, pass, t:none, setvar:tx.paranoia_level=1"/' /etc/modsecurity/crs/crs-setup.conf

# Restart Apache
systemctl restart apache2

echo "Server setup complete!"
