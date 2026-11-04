#!/bin/sh
set -eu

cd /var/www/html

# Built from the runtime environment (env_file), so the values from .env are used.
php artisan config:cache --no-interaction
php artisan view:cache --no-interaction

exec "$@"
