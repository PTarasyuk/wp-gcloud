#!/usr/bin bash

set -Eeuo pipefail

if [[ "$1" == apache2* ]] || [ "$1" = 'php-fpm' ]; then
    uid="$(id -u)"
    gid="$(id -g)"
    if [ "$uid" = '0' ]; then
        case "$1" in
            apache2*)
                user="${APACHE_RUN_USER:-www-data}"
                group="${APACHE_RUN_GROUP:-www-data}"

                # strip off any '#' symbol ('#1000' is valid syntax for Apache)
                pound='#'
                user="${user#$pound}"
                group="${group#$pound}"
                ;;
            *) # php-fpm
                user='www-data'
                group='www-data'
                ;;
        esac
    else
        user="$uid"
        group="$gid"
    fi

    if [ ! -e index.php ] && [ ! -e wp-includes/version.php ]; then
        # if the directory exists and WordPress doesn't appear to be installed AND the permissions of it are root:root, let's chown it (likely a Docker-created directory)
        if [ "$uid" = '0' ] && [ "$(stat -c '%u:%g' .)" = '0:0' ]; then
            chown "$user:$group" .
        fi

        echo >&2 "WordPress not found in $PWD - copying now..."
        if [ -n "$(find -mindepth 1 -maxdepth 1 -not -name wp-content)" ]; then
            echo >&2 "WARNING: $PWD is not empty! (copying anyhow)"
        fi
        sourceTarArgs=(
            --create
            --file -
            --directory /usr/src/wordpress
            --owner "$user" --group "$group"
        )
        targetTarArgs=(
            --extract
            --file -
        )
        if [ "$uid" != '0' ]; then
            # avoid "tar: .: Cannot utime: Operation not permitted" and "tar: .: Cannot change mode to rwxr-xr-x: Operation not permitted"
            targetTarArgs+=( --no-overwrite-dir )
        fi
        # loop over "pluggable" content in the source, and if it already exists in the destination, skip it
        # https://github.com/docker-library/wordpress/issues/506 ("wp-content" persisted, "akismet" updated, WordPress container restarted/recreated, "akismet" downgraded)
        for contentPath in \
            /usr/src/wordpress/.htaccess \
            /usr/src/wordpress/wp-content/*/*/ \
        ; do
            contentPath="${contentPath%/}"
            [ -e "$contentPath" ] || continue
            contentPath="${contentPath#/usr/src/wordpress/}" # "wp-content/plugins/akismet", etc.
            if [ -e "$PWD/$contentPath" ]; then
                echo >&2 "WARNING: '$PWD/$contentPath' exists! (not copying the WordPress version)"
                sourceTarArgs+=( --exclude "./$contentPath" )
            fi
        done
        tar "${sourceTarArgs[@]}" . | tar "${targetTarArgs[@]}"
        echo >&2 "Complete! WordPress has been successfully copied to $PWD"
    fi

    wpEnvs=( "${!WORDPRESS_@}" )
    if [ ! -s wp-config.php ] && [ "${#wpEnvs[@]}" -gt 0 ]; then
        for wpConfigDocker in \
            wp-config-docker.php \
            /usr/src/wordpress/wp-config-docker.php \
        ; do
            if [ -s "$wpConfigDocker" ]; then
                echo >&2 "No 'wp-config.php' found in $PWD, but 'WORDPRESS_...' variables supplied; copying '$wpConfigDocker' (${wpEnvs[*]})"
                # using "awk" to replace all instances of "put your unique phrase here" with a properly unique string (for AUTH_KEY and friends to have safe defaults if they aren't specified with environment variables)
                awk '
                    /put your unique phrase here/ {
                        cmd = "head -c1m /dev/urandom | sha1sum | cut -d\\  -f1"
                        cmd | getline str
                        close(cmd)
                        gsub("put your unique phrase here", str)
                    }
                    { print }
                ' "$wpConfigDocker" > wp-config.php
                if [ "$uid" = '0' ]; then
                    # attempt to ensure that wp-config.php is owned by the run user
                    # could be on a filesystem that doesn't allow chown (like some NFS setups)
                    chown "$user:$group" wp-config.php || true
                fi
                break
            fi
        done
    fi

    if ! su -s /bin/bash -c "wp core is-installed --path=$PWD" $user 2>/dev/null; then
        echo >&2 "WordPress is not installed. Starting installation..."

        # Install WordPress
        su -s /bin/bash -c "wp core install \
           --url=$WORDPRESS_URL \
           --title=$WORDPRESS_TITLE \
           --admin_user=$WORDPRESS_DB_USER \
           --admin_password=$WORDPRESS_DB_PASSWORD \
           --admin_email=$WORDPRESS_ADMIN_EMAIL \
           --path=$PWD" $user
        
        echo >&2 "WordPress installation completed."
    else
        echo >&2 "WordPress is already installed."
    fi

    # Update WordPress Site
    if su -s /bin/bash -c "wp core is-installed --path=$PWD" $user; then
        # Activate theme 'kidsko.pl'
        if su -s /bin/bash -c "wp theme list --field=name --path=$PWD" $user | grep -q 'kidsko'; then
            if ! su -s /bin/bash -c "wp theme is-active kidsko --path=$PWD" $user; then
                su -s /bin/bash -c "wp theme activate kidsko --path=$PWD" $user
                echo >&2 "Theme 'kidsko.pl' activated."
            else
                echo >&2 "Theme 'kidsko.pl' is already activated."
            fi        
        else
            echo >&2 "Theme 'kidsko.pl' is not installed."
        fi

        # Activate plugin 'interactivity-block'
        if su -s /bin/bash -c "wp plugin list --field=name --path=$PWD" $user | grep -q 'interactivity-block'; then
            if ! su -s /bin/bash -c "wp plugin is-active interactivity-block --path=$PWD" $user; then
                su -s /bin/bash -c "wp plugin activate interactivity-block --path=$PWD" $user
                echo >&2 "Plugin 'interactivity-block' activated."
            else
                echo >&2 "Plugin 'interactivity-block' is already activated."
            fi
        else
            echo >&2 "Plugin 'interactivity-block' is not installed."
        fi
    else
        echo >&2 "WordPress is not installed."
    fi

    # Get the list of inactive plugins
    inactive_plugins=$(su -s /bin/bash -c "wp plugin list --status=inactive --field=name --path=$PWD" $user)

    echo >&2 "Inactive plugins: $inactive_plugins"

    # If there are any inactive plugins, delete them
    if [ -n "$inactive_plugins" ]; then
        for plugin in $inactive_plugins; do
            su -s /bin/bash -c "wp plugin delete $plugin --path=$PWD" $user
            echo >&2 "Deleting plugin: $plugin"
        done
        echo >&2 "Inactive plugins deleted."
    fi

    # Get the list of inactive themes
    inactive_themes=$(su -s /bin/bash -c "wp theme list --status=inactive --field=name --path=$PWD" $user)

    echo >&2 "Inactive themes: $inactive_themes"

    # If there are any inactive themes, delete them
    if [ -n "$inactive_themes" ]; then
        for theme in $inactive_themes; do
            su -s /bin/bash -c "wp theme delete $theme --path=$PWD" $user
            echo >&2 "Deleting theme: $theme"
        done
        echo >&2 "Inactive themes deleted."
    fi

fi

exec "$@"