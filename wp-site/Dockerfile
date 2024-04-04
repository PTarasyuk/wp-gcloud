FROM wordpress:6.5.0-php8.3-apache
WORKDIR /var/www/html
EXPOSE 80

COPY wp-config.php wp-config.php
COPY wp-content wp-content
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENV WORDPRESS_CLI_VERSION 2.10.0

RUN chmod +x /usr/local/bin/docker-entrypoint.sh; \
    set -ex; \
    curl -o /usr/local/bin/wp -fL "https://github.com/wp-cli/wp-cli/releases/download/v${WORDPRESS_CLI_VERSION}/wp-cli-${WORDPRESS_CLI_VERSION}.phar"; \
    chmod +x /usr/local/bin/wp; \
    wp --allow-root --version

ENTRYPOINT [ "/bin/bash", "docker-entrypoint.sh" ]
CMD ["apache2-foreground"]