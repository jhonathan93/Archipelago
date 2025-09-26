FROM php:8.2-apache

RUN docker-php-ext-install pdo_mysql mysqli

RUN pecl install redis && docker-php-ext-enable redis

RUN a2enmod rewrite

RUN echo "display_errors = On" >> /usr/local/etc/php/php.ini-development && \
    echo "error_reporting = E_ALL" >> /usr/local/etc/php/php.ini-development && \
    cp /usr/local/etc/php/php.ini-development /usr/local/etc/php/php.ini

WORKDIR /var/www/html