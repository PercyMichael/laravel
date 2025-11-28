# --- Stage 1: Builder ---
FROM composer:2 AS builder

# Set working directory
WORKDIR /app

# Copy composer files and install dependencies
COPY composer.json composer.lock ./
RUN composer install --prefer-dist --no-ansi --no-interaction --no-progress --no-scripts --optimize-autoloader

# Copy the rest of the application code
COPY . .

# Generate TypeScript types for Inertia pages
RUN php artisan wayfinder:generate --with-form

# Run artisan commands for production optimization (optional, can also be done in Dokploy post-deploy hook)
# RUN php artisan optimize:clear
# RUN php artisan optimize

# --- Stage 2: Node Builder ---
FROM node:20-alpine AS node_builder

# Install PHP for the wayfinder plugin
RUN apk add --no-cache php

WORKDIR /app

# Copy vendor directory from builder stage
COPY --from=builder /app/vendor /app/vendor

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# --- Stage 3: PHP-FPM Runtime ---
FROM php:8.3-fpm-alpine AS runtime

# Install system dependencies and PHP extensions for Laravel
RUN apk add --no-cache \
    nginx \
    supervisor \
    postgresql-libs \
    postgresql-dev \
    mysql-client \
    imagemagick \
    libzip \
    libzip-dev \
    libpng \
    libpng-dev \
    jpeg \
    libjpeg-turbo-dev \
    freetds \
    freetds-dev \
    # ... add other required libs ...
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql opcache zip exif pcntl \
    && docker-php-ext-configure gd --with-jpeg \
    && docker-php-ext-install gd

# Configure PHP-FPM to listen on port 9000
RUN sed -i 's/listen = .*/listen = 127.0.0.1:9000/' /usr/local/etc/php-fpm.d/www.conf

# Set working directory
WORKDIR /app

# Copy code and vendor directory from the builder stage
COPY --from=builder /app /app

# Copy built frontend assets from the node builder stage
COPY --from=node_builder /app/public/build /app/public/build

# Configure Nginx for Laravel (create your own nginx.conf or use a default one)
COPY docker/nginx/nginx.conf /etc/nginx/http.d/default.conf

COPY docker/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Set permissions
RUN chown -R www-data:www-data /app/storage /app/bootstrap/cache

# Expose port (Dokploy will handle port mapping)
EXPOSE 80

# Start supervisor to manage nginx and php-fpm processes
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Ensure you have supervisor and nginx config files in a 'docker' directory in your project
