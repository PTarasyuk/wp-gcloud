FROM wordpress:6.4.3-php8.3-apache
#WORKDIR /var/www/html
EXPOSE 80

COPY . /var/www/html

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && copy wp-cli.phar /usr/local/bin/wp \
    && copy docker-entrypoint.sh /usr/local/bin \
    && chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]


CMD ["apache2-foreground"]