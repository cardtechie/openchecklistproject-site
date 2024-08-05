#!/bin/sh
set -ex

cd /var/www/app/

LARAVEL_DIRS="storage/app/public storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache"

mkdir -p ${LARAVEL_DIRS}
chown -R www-data:www-data ${LARAVEL_DIRS}
chmod -R 775 ${LARAVEL_DIRS}
