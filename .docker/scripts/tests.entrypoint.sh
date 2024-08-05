#!/bin/sh
set -ex

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
    set -- php-fpm "$@"
fi

cd /var/www/app
# refresh libraries now that our code is bind-mounted in place
composer dump-autoload

# run default entrypoint
#/var/www/app/.docker/scripts/entrypoint.sh

exec "$@"
