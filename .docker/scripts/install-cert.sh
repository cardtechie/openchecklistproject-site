#!/bin/sh
set -ex

# In order to get a letsencrypt cert, port 80 must be left open
# to acquire the cert. It can then be closed if desired. Also,
# for acquisition and renewal, only ports 80 and 443 will be used.

if [ -d /etc/letsencrypt/live/admin.tradingcardapi.com ]; then
    echo "Certs already exist on the server"
    certbot renew --renew-hook 'service nginx reload'
else
    certbot --nginx -m josh@picklewagon.com -d admin.tradingcardapi.com --agree-tos certonly
    cat /var/log/letsencrypt/letsencrypt.log
fi
