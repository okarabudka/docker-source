# syntax=docker/dockerfile:1

# One Dockerfile for every PHP version and flavour. Build context is the repository root.
#   PHP_VERSION  8.1 .. 8.5
#   VARIANT      apache | fpm
#   OS           trixie | alpine (alpine only with fpm)
# Targets: dev (Composer, Xdebug, git, msmtp) and prod (default, last stage).
ARG PHP_VERSION=8.5
ARG VARIANT=fpm
ARG OS=trixie
ARG UID=1000
ARG GID=1000

FROM mlocati/php-extension-installer:2.13.2 AS ext-installer
FROM composer:2 AS composer

FROM php:${PHP_VERSION}-${VARIANT}-${OS} AS base

ARG PHP_EXTENSIONS="amqp apcu bcmath exif gd imagick intl mysqli opcache pcntl pdo_mysql pdo_pgsql redis soap sockets xsl zip"
ARG UID
ARG GID

ENV PHP_MEMORY_LIMIT=256M \
    PHP_UPLOAD_MAX_FILESIZE=32M \
    OPCACHE_VALIDATE_TIMESTAMPS=0

COPY --from=ext-installer /usr/bin/install-php-extensions /usr/local/bin/

# shadow (usermod/groupmod) is needed on Alpine for the PUID/PGID remap in the entrypoint
RUN install-php-extensions ${PHP_EXTENSIONS} \
    && if command -v apk >/dev/null; then \
        apk add --no-cache shadow \
        && addgroup -g "${GID}" app \
        && adduser -D -u "${UID}" -G app -h /home/app -s /bin/sh app; \
    else \
        groupadd -g "${GID}" app \
        && useradd -l -m -u "${UID}" -g app -s /bin/bash app; \
    fi \
    && mkdir -p /var/www/html/public \
    && chown -R app:app /var/www/html

# The BusyBox setpriv applet on Alpine lacks --reuid/--regid; util-linux setpriv has them
RUN if command -v apk >/dev/null; then apk add --no-cache setpriv; fi

COPY php/conf/php/app.ini "${PHP_INI_DIR}/conf.d/zz-app.ini"
COPY php/bin/entrypoint /usr/local/bin/entrypoint

WORKDIR /var/www/html

FROM base AS server-apache

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public \
    APACHE_RUN_USER=app \
    APACHE_RUN_GROUP=app

COPY php/conf/apache/ports.conf /etc/apache2/ports.conf
COPY php/conf/apache/vhost.conf /etc/apache2/sites-available/000-default.conf

RUN a2enmod rewrite headers expires \
    && sed -ri 's/^ServerTokens .*/ServerTokens Prod/; s/^ServerSignature .*/ServerSignature Off/' \
        /etc/apache2/conf-available/security.conf

EXPOSE 8080

# mod_status answers only local requests (Require local)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --start-interval=1s \
    CMD ["curl", "-fsS", "-o", "/dev/null", "http://127.0.0.1:8080/server-status?auto"]

ENTRYPOINT ["entrypoint"]
CMD ["apache2-foreground"]

FROM base AS server-fpm

RUN if command -v apk >/dev/null; then \
        apk add --no-cache fcgi; \
    else \
        apt-get update \
        && apt-get install -y --no-install-recommends libfcgi-bin \
        && rm -rf /var/lib/apt/lists/*; \
    fi \
    && sed -ri '/^(user|group) = /d' /usr/local/etc/php-fpm.d/www.conf

COPY php/conf/fpm/zz-app.conf /usr/local/etc/php-fpm.d/zz-app.conf
COPY php/bin/php-fpm-healthcheck /usr/local/bin/php-fpm-healthcheck

EXPOSE 9000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --start-interval=1s \
    CMD ["php-fpm-healthcheck"]

ENTRYPOINT ["entrypoint"]
CMD ["php-fpm"]

# hadolint ignore=DL3006
FROM server-${VARIANT} AS dev

ENV XDEBUG_MODE=off \
    OPCACHE_VALIDATE_TIMESTAMPS=1 \
    MAIL_HOST=mailpit \
    MAIL_PORT=1025

RUN install-php-extensions xdebug \
    && if command -v apk >/dev/null; then \
        apk add --no-cache git msmtp openssh-client unzip; \
    else \
        apt-get update \
        && apt-get install -y --no-install-recommends git msmtp openssh-client unzip \
        && rm -rf /var/lib/apt/lists/*; \
    fi \
    && cp "${PHP_INI_DIR}/php.ini-development" "${PHP_INI_DIR}/php.ini"

COPY --from=composer /usr/bin/composer /usr/local/bin/composer
COPY php/conf/php/dev.ini "${PHP_INI_DIR}/conf.d/zz-dev.ini"

ARG UID
ARG GID
USER ${UID}:${GID}

# hadolint ignore=DL3006
FROM server-${VARIANT} AS prod

RUN cp "${PHP_INI_DIR}/php.ini-production" "${PHP_INI_DIR}/php.ini"

COPY php/conf/php/prod.ini "${PHP_INI_DIR}/conf.d/zz-prod.ini"

ARG UID
ARG GID
USER ${UID}:${GID}
