FROM debian:bullseye-slim

ENV USER_ID=1000
ENV GROUP_ID=1000
ENV UNAME=developer

WORKDIR /var/www/

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        gnupg ca-certificates \
        zip unzip openssh-client rsync sudo git wget curl apt-transport-https \
    && echo "deb https://packages.sury.org/php/ bullseye main" | tee /etc/apt/sources.list.d/sury-php.list \
    && wget -qO - https://packages.sury.org/php/apt.gpg | sudo apt-key add - \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
       ghostscript \
       libmagickcore-6.q16-6-extra \
       libnss3 \
       php8.2-amqp \
       php8.2-bcmath \
       php8.2-bz2 \
       php8.2-cli \
       php8.2-common \
       php8.2-curl \
       php8.2-fpm \
       php8.2-gd \
       php8.2-gmp \
       php8.2-igbinary \
       php8.2-imagick \
       php8.2-intl \
       php8.2-maxminddb \
       php8.2-mbstring \
       php8.2-memcached \
       php8.2-msgpack \
       php8.2-mysql \
       php8.2-opcache \
       php8.2-pgsql \
       php8.2-readline \
       php8.2-redis \
       php8.2-sqlite3 \
       php8.2-vips \
       php8.2-xml \
       php8.2-yaml \
       php8.2-zip \
       php8.2-xdebug \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY configs/php8.ini /etc/php/8.2/fpm/php.ini
COPY configs/php8.ini /etc/php/8.2/cli/php.ini
COPY configs/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY configs/docker.conf /etc/php/8.2/fpm/pool.d/docker.conf
COPY configs/zz-docker.conf /etc/php/8.2/fpm/pool.d/zz-docker.conf
COPY scripts/entrypoint-php-fpm.sh /usr/local/bin/entrypoint
COPY scripts/set-puid.sh /usr/local/bin/set-puid
COPY scripts/copy-ssh-keys.sh /usr/local/bin/copy-ssh-keys
COPY scripts/add-host-alias.sh /usr/local/bin/add-host-alias

# User
RUN chmod +x /usr/local/bin/entrypoint \
            /usr/local/bin/set-puid \
            /usr/local/bin/copy-ssh-keys \
            /usr/local/bin/add-host-alias && \
    ln -s /usr/sbin/php-fpm8.2 /usr/local/bin/php-fpm && \
    groupadd --gid ${GROUP_ID} ${UNAME} && \
    useradd --uid ${USER_ID} --gid ${GROUP_ID} -m -g ${UNAME} -s /bin/bash ${UNAME} && \
    usermod -a -G sudo ${UNAME} && usermod -a -G www-data ${UNAME} && \
    echo "${UNAME} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    passwd -d ${UNAME} && \
    mkdir -p /home/${UNAME}/.ssh /var/log/php /run/php && \
    chown -R ${UNAME}:${UNAME} /home/${UNAME}/.ssh /var/log/php /run/php && \
    chmod 775 /var/log/php && \
    sed -i 's/\#\ \ \ StrictHostKeyChecking\ ask/StrictHostKeyChecking no/g' /etc/ssh/ssh_config

EXPOSE 9000

USER ${UNAME}

ENTRYPOINT ["entrypoint"]
CMD ["php-fpm"]
