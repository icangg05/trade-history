# syntax=docker/dockerfile:1

# ---------- base: FrankenPHP + ekstensi yang dipakai Laravel ----------
FROM dunglas/frankenphp:php8.4 AS base

RUN install-php-extensions pdo_mysql gd intl zip opcache pcntl bcmath exif

# mariadb-client menyediakan `mysqldump` untuk backup database di halaman admin.
RUN apt-get update \
    && apt-get install -y --no-install-recommends mariadb-client \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY docker/Caddyfile /etc/frankenphp/Caddyfile

WORKDIR /app

# ---------- dev: kode di-bind-mount, PHP mode klasik (hot reload gratis) ----------
FROM base AS dev

COPY docker/php.ini /usr/local/etc/php/conf.d/app.ini
ENV COMPOSER_ALLOW_SUPERUSER=1

# Kontainer dev berjalan sebagai user host (lihat compose.yml) supaya berkas
# unggahan lahir dengan kepemilikan yang sama di kedua sisi bind mount.
# Caddy tetap butuh dua direktori ini bisa ditulis, dan port 80 sudah bisa
# di-bind tanpa root berkat cap_net_bind_service pada binari frankenphp.
RUN chown -R 1000:1000 /data /config

EXPOSE 80

# ---------- build: vendor + aset produksi ----------
FROM base AS build

COPY docker/php.prod.ini /usr/local/etc/php/conf.d/app.ini
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist

COPY package.json package-lock.json ./
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm ci \
    && rm -rf /var/lib/apt/lists/*

COPY . .
RUN composer dump-autoload --optimize --no-dev \
    && npm run build \
    && rm -rf node_modules

# ---------- production: Octane worker mode ----------
FROM base AS production

COPY docker/php.prod.ini /usr/local/etc/php/conf.d/app.ini
COPY --from=build /app /app

RUN chown -R www-data:www-data storage bootstrap/cache

ENV APP_ENV=production
EXPOSE 80

CMD ["php", "artisan", "octane:frankenphp", "--host=0.0.0.0", "--port=80", "--workers=auto", "--max-requests=500"]
