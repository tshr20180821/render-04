FROM php:8.2-apache

WORKDIR /usr/src/app

COPY ./php.ini ${PHP_INI_DIR}/
COPY ./index.html /var/www/html/
COPY --chmod=644 .htpasswd /var/www/html/
COPY ./apache.conf /etc/apache2/sites-enabled/
COPY ./apt-fast.conf /tmp/

ENV CFLAGS="-O2 -march=native -mtune=native -fomit-frame-pointer"
ENV CXXFLAGS="$CFLAGS"
ENV LDFLAGS="-fuse-ld=gold"
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV NODE_ENV=production
ENV NODE_MAJOR=20

# binutils : strings
# ca-certificates : node.js
# curl : node.js
# default-jre : java
# libmemcached-dev : pecl memcached
# gnupg : node.js
# libonig-dev : mbstring
# libsqlite3-0 : php sqlite
# libssl-dev : pecl memcached
# libzip-dev : docker-php-ext-configure zip --with-zip
# memcached : memcached
# nodejs : nodejs
# tzdata : ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
# zlib1g-dev : pecl memcached
RUN curl -sSo /tmp/gpg https://raw.githubusercontent.com/tshr20180821/render-07/main/app/gpg \
 && chmod +x /tmp/gpg \
 && mkdir -p /etc/apt/keyrings \
 && curl -fsSL 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xA2166B8DE8BDC3367D1901C11EE2FF37CA8DA16B' | /tmp/gpg --dearmor -o /etc/apt/keyrings/apt-fast.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/apt-fast.gpg] http://ppa.launchpad.net/apt-fast/stable/ubuntu jammy main" | tee /etc/apt/sources.list.d/apt-fast.list \
 && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | /tmp/gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
 && apt-get -q update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apt-fast \
 && cp -f /tmp/apt-fast.conf /etc/ \
 && apt-fast  install -y --no-install-recommends \
  binutils \
  ca-certificates \
  curl \
  default-jre \
  libmemcached-dev \
  libonig-dev \
  libsqlite3-0 \
  libssl-dev \
  libzip-dev \
  memcached \
  nodejs \
  tzdata \
  zlib1g-dev \
 && MAKEFLAGS="-j $(nproc)" pecl install apcu >/dev/null \
 && docker-php-ext-enable apcu \
 && MAKEFLAGS="-j $(nproc)" pecl install memcached \
 && docker-php-ext-enable memcached \
 && docker-php-ext-configure zip --with-zip \
 && docker-php-ext-install -j$(nproc) \
  pdo_mysql \
  mysqli \
  mbstring \
  >/dev/null \
 && npm install \
 && npm update -g \
 && npm audit fix \
 && apt-get upgrade -y --no-install-recommends \
 && npm cache clean --force \
 && pecl clear-cache \
 && apt-get purge -y --auto-remove gcc libc6-dev make \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /var/www/html/auth \
 && mkdir -p /var/www/html/phpmyadmin \
 && a2dissite -q 000-default.conf \
 && a2enmod -q authz_groupfile rewrite \
 && ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime \
 && curl -sS \
  -LO https://github.com/xerial/sqlite-jdbc/releases/download/3.43.2.0/sqlite-jdbc-3.43.2.0.jar \
  -LO https://repo1.maven.org/maven2/org/slf4j/slf4j-api/2.0.9/slf4j-api-2.0.9.jar \
  -LO https://repo1.maven.org/maven2/org/slf4j/slf4j-nop/2.0.9/slf4j-nop-2.0.9.jar \
  -O https://raw.githubusercontent.com/tshr20180821/render-07/main/app/LogOperation.jar \
  -o /tmp/phpMyAdmin.tar.xz https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.tar.xz \
 && tar xf /tmp/phpMyAdmin.tar.xz --strip-components=1 -C /var/www/html/phpmyadmin \
 && rm /tmp/phpMyAdmin.tar.xz \
 && chown www-data:www-data /var/www/html/phpmyadmin -R

COPY ./config.inc.php /var/www/html/phpmyadmin/
COPY --chmod=755 ./app/log.sh /usr/src/app/
COPY ./app/* /usr/src/app/

COPY ./auth/*.php /var/www/html/auth/

# CMD ["bash","/usr/src/app/start.sh"]
ENTRYPOINT ["bash","/usr/src/app/start.sh"]
