#!/bin/bash

# Downloads the 6.4.3 version of WordPress.
# Overwrites existing core files but preserves `wp-config.php` and `wp-content`.
# Adds default themes/plugins if they're missing.
wp core download --version=6.4.3 --force --skip-content --path=/var/www/html --allow-root

# Check if WordPress is installed
if ! wp core is-installed --path=/var/www/html --allow-root; then
    echo "WordPress is not installed. Starting installation..."

    # Install WordPress
    wp core install \
       --url="http://localhost" \
       --title="Example Site" \
       --admin_user="admin" \
       --admin_password="password" \
       --admin_email="admin@example.com" \
       --path=/var/www/html \
       --allow-root
    
    echo "WordPress installation completed."
else
    echo "WordPress is already installed."
fi

# Update WordPress Site
if wp core is-installed --path=/var/www/html --allow-root; then
    # Activate theme 'kidsko.pl'
    if wp theme list --field=name --path=/var/www/html --allow-root | grep -q 'kidsko'; then
        if ! wp theme is-active kidsko --path=/var/www/html --allow-root; then
            wp theme activate kidsko --path=/var/www/html --allow-root
            echo "Theme 'kidsko.pl' activated."
        else
            echo "Theme 'kidsko.pl' is already activated."
        fi        
    else
        echo "Theme 'kidsko.pl' is not installed."
    fi

    # Activate plugin 'interactivity-block'
    if wp plugin list --field=name --path=/var/www/html --allow-root | grep -q 'interactivity-block'; then
        if ! wp plugin is-active interactivity-block --path=/var/www/html --allow-root; then
            wp plugin activate interactivity-block --path=/var/www/html --allow-root
            echo "Plugin 'interactivity-block' activated."
        else
            echo "Plugin 'interactivity-block' is already activated."
        fi
    else
        echo "Plugin 'interactivity-block' is not installed."
    fi
else
    echo "WordPress is not installed."
fi

# Get the list of inactive plugins
inactive_plugins=$(wp plugin list --status=inactive --field=name --path=/var/www/html --allow-root)

# If there are any inactive plugins, delete them
if [ -n "$inactive_plugins" ]; then
    wp plugin delete $inactive_plugins --path=/var/www/html --allow-root
    echo "Inactive plugins deleted."
fi

# Get the list of inactive themes
inactive_themes=$(wp theme list --status=inactive --field=name --path=/var/www/html --allow-root)

# If there are any inactive themes, delete them
if [ -n "$inactive_themes" ]; then
    wp theme delete $inactive_themes --path=/var/www/html --allow-root
    echo "Inactive themes deleted."
fi

# Execute the container's main command (apache2-foreground or other)
exec "$@"