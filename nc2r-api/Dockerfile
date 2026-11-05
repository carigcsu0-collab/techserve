# syntax=docker/dockerfile:1

FROM php:8.3-apache

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_NO_INTERACTION=1 \
    APACHE_DOCUMENT_ROOT=/var/www/html/public

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libzip-dev libpng-dev libjpeg62-turbo-dev libfreetype6-dev libonig-dev unzip ffmpeg \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" pdo_mysql mbstring bcmath zip gd opcache \
 && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

RUN a2enmod rewrite headers \
 && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY docker/php/hardening.ini $PHP_INI_DIR/conf.d/zz-hardening.ini
COPY docker/php/worker.ini $PHP_INI_DIR/conf.d/zz-worker.ini
COPY docker/apache/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY docker/apache/zz-hardening.conf /etc/apache2/conf-available/zz-hardening.conf
RUN a2enconf zz-hardening

WORKDIR /var/www/html

# Dependencies first so this layer is cached until composer.* changes
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-progress --prefer-dist --optimize-autoloader --no-scripts

# .dockerignore keeps .env, database files, logs and storage out of the image
COPY . .
RUN composer dump-autoload --optimize --no-dev \
 && mkdir -p storage/app/public storage/app/private storage/app/tmp storage/framework/cache/data \
      storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
 && ln -sfn /var/www/html/storage/app/public public/storage \
 && chown -R www-data:www-data storage bootstrap/cache \
 && chmod -R u+rwX,g+rwX,o-rwx storage bootstrap/cache

COPY docker/entrypoint.sh /usr/local/bin/nc2r-entrypoint
RUN chmod 0755 /usr/local/bin/nc2r-entrypoint

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD php -r 'exit(@file_get_contents("http://127.0.0.1/up") === false ? 1 : 0);'

ENTRYPOINT ["nc2r-entrypoint"]
CMD ["apache2-foreground"]
