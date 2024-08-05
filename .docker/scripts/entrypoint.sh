#!/bin/sh
set -ex

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
    set -- php-fpm "$@"
fi

# usage: process_init_file FILENAME
#    ie: process_init_file foo.sh
# (process a single initializer file, based on its extension. we define this
# function here, so that initializer scripts (*.sh) can use the same logic,
# potentially recursively, or override the logic used in subsequent calls)
process_init_file() {
    local f="$1"; shift
    case "$f" in
        *.sh)     echo "$0: running $f"; . "$f" ;;
        *)        echo "$0: ignoring $f" ;;
    esac
    echo
}

# See if we have anything to provision
INIT_DIR=/var/www/app/.docker/init.d
PROVISIONING_FILE=${INIT_DIR}/.provisioned

# Execute scripts in init.d if we haven't already done so
if [ ! -f ${PROVISIONING_FILE} ]; then
    echo "Running init.d scripts..."
    for f in ${INIT_DIR}/*; do
        process_init_file "$f"
    done

    # Indicate we've finished
    touch ${PROVISIONING_FILE}
fi

exec "$@"
