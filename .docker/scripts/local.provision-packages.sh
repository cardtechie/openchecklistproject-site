#!/bin/sh
set -ex

cd /var/www/app

# Sync over our vendor/node libraries
rsync -aqW --inplace /var/www/vendor/ /var/www/app/vendor/ 2>&1 &
rsync -aqW --inplace /var/www/node_modules/ /var/www/app/node_modules/ 2>&1 &
wait

# For some reason, symlinks in vendor/bin aren't being copied over correctly.
rm -rfv vendor/bin
composer install

# Re-run composer dump-autoload
composer dump-autoload
