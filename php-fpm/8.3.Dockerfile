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
       php8.3-amqp \
       php8.3-bcmath \
       php8.3-bz2 \
       php8.3-cli \
       php8.3-common \
       php8.3-curl \
       php8.3-fpm \
       php8.3-gd \
       php8.3-gmp \
       php8.3-igbinary \
       php8.3-imagick \
       php8.3-intl \
       php8.3-maxminddb \
       php8.3-mbstring \
       php8.3-memcached \
       php8.3-msgpack \
       php8.3-mysql \
       php8.3-opcache \
       php8.3-pgsql \
       php8.3-readline \
       php8.3-redis \
       php8.3-sqlite3 \
       php8.3-vips \
       php8.3-xml \
       php8.3-yaml \
       php8.3-zip \
       php8.3-xdebug \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY configs/php8.ini /etc/php/8.3/fpm/php.ini
COPY configs/php8.ini /etc/php/8.3/cli/php.ini
COPY configs/www.conf /etc/php/8.3/fpm/pool.d/www.conf
COPY configs/docker.conf /etc/php/8.3/fpm/pool.d/docker.conf
COPY configs/zz-docker.conf /etc/php/8.3/fpm/pool.d/zz-docker.conf
COPY scripts/entrypoint-php-fpm.sh /usr/local/bin/entrypoint
COPY scripts/set-puid.sh /usr/local/bin/set-puid
COPY scripts/copy-ssh-keys.sh /usr/local/bin/copy-ssh-keys
COPY scripts/add-host-alias.sh /usr/local/bin/add-host-alias

# User
RUN chmod +x /usr/local/bin/entrypoint \
            /usr/local/bin/set-puid \
            /usr/local/bin/copy-ssh-keys \
            /usr/local/bin/add-host-alias && \
    ln -s /usr/sbin/php-fpm8.3 /usr/local/bin/php-fpm && \
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
