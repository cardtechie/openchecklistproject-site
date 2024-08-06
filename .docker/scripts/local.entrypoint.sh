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

#/var/www/app/.docker/scripts/wait-for-it.sh mysql:3306 -t 60 --strict -- echo mysql database is ready

exec "$@"
