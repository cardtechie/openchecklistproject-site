#!/bin/sh
set -ex

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
    set -- php-fpm "$@"
fi

cd /var/www/app

# Run the default entrypoint script here - this will check for init/provisioning scripts and run them;
# We do this here to ensure that we are fully provisioned before we continue
/var/www/app/.docker/scripts/entrypoint.sh

# Setup the laravel directory structure
/var/www/app/.docker/scripts/laravel.sh

# Update the certificate if necessary
/var/www/app/.docker/scripts/install-cert.sh

# refresh libraries now that our code is bind-mounted in place optimized for production
composer dump-autoload -o

# These are commands run INSIDE of the container after an update is deployed
# These commands will run for EVERY code update
php artisan migrate --database=mysql --force
php artisan migrate --database=cards --force
php artisan queue:restart
php artisan view:cache

php artisan ziggy:generate --url=${APP_URL}
npm run build

exec "$@"
