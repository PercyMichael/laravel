# --- Stage 1: Builder ---
FROM composer:2 AS builder

# Set working directory
WORKDIR /app

# Copy composer files and install dependencies
COPY composer.json composer.lock ./
RUN composer install --prefer-dist --no-ansi --no-interaction --no-progress --no-scripts --optimize-autoloader

# Copy the rest of the application code
COPY . .

# Run artisan commands for production optimization (optional, can also be done in Dokploy post-deploy hook)
# RUN php artisan optimize:clear
# RUN php artisan optimize

# Build frontend assets (adjust for your specific build process, e.g., using Node)
# If you have frontend assets to build, you can add a Node.js stage here

# --- Stage 2: PHP-FPM Runtime ---
FROM php:8.3-fpm-alpine AS runtime

# Install system dependencies and PHP extensions for Laravel
RUN apk add --no-cache \
    nginx \
    supervisor \
    postgresql-libs \
    mysql-client \
    imagemagick \
    libzip \
    libpng \
    jpeg \
    freetds \
    freetds-dev \
    # ... add other required libs ...
    && docker-php-ext-install pdo pdo_mysql opcache zip exif pcntl \
    && docker-php-ext-configure gd --with-jpeg \
    && docker-php-ext-install gd

# Set working directory
WORKDIR /app

# Copy code and vendor directory from the builder stage
COPY --from=builder /app /app

# Configure Nginx for Laravel (create your own nginx.conf or use a default one)
COPY docker/nginx/nginx.conf /etc/nginx/http.d/default.conf

# Set permissions
RUN chown -R www-data:www-data /app/storage /app/bootstrap/cache

# Expose port (Dokploy will handle port mapping)
EXPOSE 80

# Start supervisor to manage nginx and php-fpm processes
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Ensure you have supervisor and nginx config files in a 'docker' directory in your project
