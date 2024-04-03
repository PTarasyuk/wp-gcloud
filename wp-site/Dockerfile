FROM wordpress:6.4.3-php8.3-apache
EXPOSE 80

COPY wp-config.php /var/www/html/wp-config.php
COPY wp-content /var/www/html/wp-content
COPY docker-entrypoint.sh /usr/local/bin/

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
RUN chmod +x wp-cli.phar
RUN mv wp-cli.phar /usr/local/bin/wp
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["apache2-foreground"]