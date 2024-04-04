FROM wordpress:6.4.3-php8.3-apache
WORKDIR /var/www/html
EXPOSE 80

COPY wp-config.php wp-config.php
COPY wp-content wp-content
COPY docker-entrypoint.sh /user/local/bin/

RUN chmod +x wp-init.sh \
    && curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

ENTRYPOINT [ "docker-entrypoint.sh" ]
CMD ["apache2-foreground"]