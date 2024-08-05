#!/bin/sh
set -ex

cd /var/www/app

php artisan migrate
