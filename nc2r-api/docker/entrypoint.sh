#!/bin/sh
set -eu

cd /var/www/html

# storage/app is a bind mount to the HDD. Create its folders on first start.
# chown can fail on Docker Desktop (Windows) bind mounts; those folders are still writable there.
mkdir -p storage/app/public storage/app/private storage/app/tmp
chown -R www-data:www-data storage/app 2>/dev/null || true

# Built from the runtime environment (env_file), so the values from .env are used.
php artisan config:cache --no-interaction
php artisan view:cache --no-interaction

exec "$@"
