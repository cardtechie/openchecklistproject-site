FROM php:8.3-fpm AS build

# PHP / FPM config defaults that we set via environment variables
ENV PHP_OPCACHE_ENABLE=0 \
    PHP_OPCACHE_MEMORY_CONSUMPTION=64 \
    PHP_OPCACHE_MAX_ACCELERATED_FILES=2000 \
    PHP_OPCACHE_REVALIDATE_FREQ=2 \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=1 \
    PHP_OPCACHE_INTERNED_STRINGS_BUFFER=4 \
    PHP_OPCACHE_FAST_SHUTDOWN=0 \
    PHP_OPCACHE_BLACKLIST_FILENAME="" \
    PHP_UPLOAD_MAX_FILESIZE=5G \
    PHP_POST_MAX_SIZE=5G \
    PHP_LOG_ERRORS=On \
    PHP_ERROR_LOG=/dev/stderr \
    PHP_SHORT_OPEN_TAG=On \
    FPM_PM=dynamic \
    FPM_PM_MAX_CHILDREN=50 \
    FPM_PM_START_SERVERS=4 \
    FPM_PM_MIN_SPARE_SERVERS=4 \
    FPM_PM_MAX_SPARE_SERVERS=8

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_VENDOR_DIR=/var/www/vendor \
    COMPOSER_HOME=/composer \
    NPM_CONFIG_LOGLEVEL=info \
    NODE_ENV=development \
    NODE_PATH=/var/www/node_modules

# XDEBUG Settings
ENV XDEBUG_ENABLED=0 \
    XDEBUG_AUTOSTART=off \
    XDEBUG_CONF_FILE=docker-php-ext-xdebug.ini \
    XDEBUG_CONNECT_BACK_PORT=9000 \
    XDEBUG_CONNECT_BACK=0 \
    XDEBUG_REMOTE_HOST=localhost \
    XDEBUG_REMOTE_LOG=/var/www/app/storage/logs/xdebug.log \
    FASTCGI_READ_TIMEOUT=60s

RUN apt-get update && apt-get install --no-install-recommends --no-install-suggests -y \
    apt-transport-https \
    ca-certificates \
    curl \
    dirmngr \
    dos2unix \
    git \
    g++ \
    jq \
    libedit-dev \
    libfcgi0ldbl \
    libfreetype6-dev \
    libicu-dev \
    libjpeg62-turbo-dev \
    libnss3-dev \
    libmcrypt-dev \
    libpq-dev \
    libreadline-dev \
    libssl-dev \
    libzip-dev \
    openssh-client \
    openssl \
    rsync \
    sqlite3 \
    supervisor \
    unzip \
    wget \
    zip \
    && rm -rf /var/lib/apt/lists/*

#RUN apt-get -y install chromium-browser xvfb gtk2-engines-pixbuf xfonts-cyrillic xfonts-100dpi xfonts-75dpi xfonts-base xfonts-scalable imagemagick x11-apps
RUN docker-php-ext-configure opcache --enable-opcache

# Install extensions using the helper script provided by the base image
RUN docker-php-ext-install \
    opcache \
    pdo \
    pdo_mysql \
    intl \
    zip

#
# XDEBUG INSTALL
#
# install xdebug, setup environment variables, and create xdebug enablement script
RUN docker-php-source extract \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && docker-php-source delete \
    && mkdir -p "${PHP_INI_DIR}/../mods-available" \
    && mv "${PHP_INI_DIR}/conf.d/${XDEBUG_CONF_FILE}" "${PHP_INI_DIR}/../mods-available" \
    && { \
        echo ""; \
        echo "[xdebug]"; \
        echo "xdebug.remote_enable = ${XDEBUG_ENABLED}"; \
        echo "xdebug.remote_autostart = ${XDEBUG_AUTOSTART}"; \
        echo "xdebug.remote_connect_back = ${XDEBUG_CONNECT_BACK}"; \
        echo "xdebug.remote_host = ${XDEBUG_REMOTE_HOST}"; \
        echo "xdebug.remote_port = ${XDEBUG_CONNECT_BACK_PORT}"; \
        echo "xdebug.remote_log = ${XDEBUG_REMOTE_LOG}"; \
        echo "xdebug.remote_handler = dbgp"; \
        echo "xdebug.max_nesting_level = 1000"; \
    } >> "${PHP_INI_DIR}/../mods-available/${XDEBUG_CONF_FILE}"

RUN apt-get update && apt-get install --no-install-recommends --no-install-suggests -y \
    nginx \
    certbot \
    python3-certbot-nginx \
    && rm -rf /var/lib/apt/lists/*

# Forward nginx request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

# Copy the Composer PHAR from the Composer image into our image
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Copy node into our image
COPY --from=node:18 /usr/local/bin/node /usr/local/bin/node
RUN ln -s /usr/local/bin/node /usr/local/bin/nodejs
COPY --from=node:18 /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm

# Copy mysqldump into our image
COPY --from=mysql:8.0 /usr/bin/mysqldump /usr/bin/mysqldump
COPY --from=mysql:8.0 /usr/bin/mysql /usr/bin/mysql

# add bitbucket and github to known hosts for ssh needs
WORKDIR /root/.ssh
RUN chmod 0600 /root/.ssh \
    && ssh-keyscan -t rsa bitbucket.org >> known_hosts \
    && ssh-keyscan -t rsa github.com >> known_hosts

ENV PATH="/composer/vendor/bin:/var/www/app/vendor/bin:/var/www/app/node_modules/.bin:$PATH"

# Install composer packages
WORKDIR /var/www/app
COPY --chown=www-data:www-data ./composer.json ./composer.lock ./
RUN composer install --no-scripts --no-autoloader --ansi --no-interaction
RUN git config --global --add safe.directory /var/www/app

WORKDIR /var/www
COPY --chown=www-data:www-data ./package.json ./package-lock.json ./
RUN npm install

ENV COMPOSER_VENDOR_DIR=/var/www/app/vendor \
    NODE_PATH=/var/www/app/node_modules

WORKDIR /var/www/app
COPY ./.docker/config/php.app.ini /usr/local/etc/php/conf.d/app.ini
COPY ./.docker/config/local.phpfpm-app.conf /usr/local/etc/php-fpm.d/zzz-app.conf
COPY ./.docker/config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY ./.docker/config/nginx.conf /etc/nginx/nginx.conf
COPY ./.docker/config/nginx-laravel.conf /etc/nginx/conf.d/server/nginx-laravel.conf
COPY ./.docker/config/nginx-status.conf /etc/nginx/conf.d/server/nginx-status.conf
COPY ./.docker/config/nginx-site-prod.conf /etc/nginx/conf.d/default.conf

# Copy in app code as late as possible, as it changes the most
COPY --chown=www-data:www-data . .

# Create symlinks into /var/www/app. We do this so the image has these available in the app directory,
# but also to ensure that when we bind-mount code in a dev enviroment these directories are still available
# to copy into the local dev environment
RUN ln -s /var/www/vendor /var/www/app/vendor \
    && ln -s /var/www/node_modules /var/www/app/node_modules

# Copy the .env.local as the base for environment variables within the image. Dev systems will bind-mount on top of
# this and instead pass the environment values into the container environment through the compose env_file values.
# But we still need this here for other environments so we have a reasonable set of default values specified for the
# application layer through the container's environment vars.
RUN cp .env.local .env

#RUN composer dump-autoload -o
# RUN npm run prod

# Run entrypoint
RUN chmod 775 ./.docker/scripts/*.sh
ENTRYPOINT ["/var/www/app/.docker/scripts/entrypoint.sh"]

EXPOSE 80 443

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
