FROM php:8.2-apache

EXPOSE 80

SHELL ["/bin/bash", "-c"]

WORKDIR /usr/src/app

ENV CFLAGS="-O2 -march=native -mtune=native -fomit-frame-pointer"
ENV CXXFLAGS="$CFLAGS"
ENV LDFLAGS="-fuse-ld=gold"
ENV NODE_ENV=production
ENV NODE_MAJOR=20

COPY ./php.ini ${PHP_INI_DIR}/
COPY ./index.html ./robots.txt /var/www/html/
COPY --chmod=644 .htpasswd /var/www/html/
COPY ./apache.conf /etc/apache2/sites-enabled/
COPY ./apt-fast.conf /tmp/
COPY ./app/package.json ./

ENV SQLITE_JDBC_VERSION="3.44.0.0"

# https://github.com/xerial/sqlite-jdbc/releases/download/$SQLITE_JDBC_VERSION/sqlite-jdbc-$SQLITE_JDBC_VERSION.jar
# https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.tar.xz
# https://repo1.maven.org/maven2/org/slf4j/slf4j-api/2.0.9/slf4j-api-2.0.9.jar
# https://repo1.maven.org/maven2/org/slf4j/slf4j-nop/2.0.9/slf4j-nop-2.0.9.jar

# binutils : strings
# ca-certificates : node.js
# curl : node.js
# default-jre-headless : java
# libmemcached-dev : pecl memcached
# libonig-dev : mbstring
# libsasl2-modules : sasl
# libsqlite3-0 : php sqlite
# libssl-dev : pecl memcached
# libzip-dev : docker-php-ext-configure zip --with-zip
# memcached : memcached
# nodejs : nodejs
# sasl2-bin : sasl
# tzdata : ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
# zlib1g-dev : pecl memcached
RUN dpkg -l \
 && echo "https://raw.githubusercontent.com/tshr20180821/render-07/main/app/sqlite-jdbc-$SQLITE_JDBC_VERSION.jar" >download.txt \
 && echo "https://raw.githubusercontent.com/tshr20180821/render-07/main/app/phpMyAdmin-5.2.1-all-languages.tar.xz" >>download.txt \
 && echo "https://raw.githubusercontent.com/tshr20180821/render-07/main/app/slf4j-api-2.0.9.jar" >>download.txt \
 && echo "https://raw.githubusercontent.com/tshr20180821/render-07/main/app/slf4j-nop-2.0.9.jar" >>download.txt \
 && echo "https://raw.githubusercontent.com/tshr20180821/render-07/main/app/LogOperation.jar" >>download.txt \
 && echo "https://raw.githubusercontent.com/tshr20180821/render-07/main/app/gpg" >>download.txt \
 && time xargs -P2 -n1 curl -sSO <download.txt \
 && chmod +x ./gpg \
 && mkdir -p /etc/apt/keyrings \
 && curl -fsSL 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xA2166B8DE8BDC3367D1901C11EE2FF37CA8DA16B' | ./gpg --dearmor -o /etc/apt/keyrings/apt-fast.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/apt-fast.gpg] http://ppa.launchpad.net/apt-fast/stable/ubuntu jammy main" | tee /etc/apt/sources.list.d/apt-fast.list \
 && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | ./gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
 && echo "deb http://deb.debian.org/debian bookworm-backports main contrib non-free" | tee /etc/apt/sources.list.d/backports.list \
 && echo "apt-get -q update" \
 && time apt-get -q update \
 && echo "apt-get -q install" \
 && time DEBIAN_FRONTEND=noninteractive apt-get -q install -y --no-install-recommends apt-fast curl/bookworm-backports \
 && cp -f /tmp/apt-fast.conf /etc/ \
 && echo "apt-fast install" \
 && time apt-fast install -y --no-install-recommends \
  binutils \
  ca-certificates \
  curl \
  default-jre-headless \
  libmemcached-dev \
  libonig-dev \
  libsasl2-modules \
  libsqlite3-0 \
  libssl-dev \
  libzip-dev \
  memcached \
  nodejs \
  sasl2-bin \
  tzdata \
  zlib1g-dev \
 && echo "pecl install apcu" \
 && time MAKEFLAGS="-j $(nproc)" pecl install apcu >/dev/null \
 && echo "docker-php-ext-enable apcu" \
 && time docker-php-ext-enable apcu \
 && echo "pecl install memcached" \
 && time MAKEFLAGS="-j $(nproc)" pecl install memcached --enable-memcached-sasl >/dev/null \
 && echo "docker-php-ext-enable memcached" \
 && time docker-php-ext-enable memcached \
 && echo "docker-php-ext-configure zip" \
 && time docker-php-ext-configure zip --with-zip >/dev/null \
 && echo "docker-php-ext-install" \
 && time docker-php-ext-install -j$(nproc) \
  pdo_mysql \
  mysqli \
  mbstring \
  opcache \
  >/dev/null \
 && echo "npm install" \
 && time npm install \
 && echo "npm update -g" \
 && time npm update -g \
 && echo "npm audit fix" \
 && time npm audit fix \
 && echo "apt-get upgrade" \
 && time apt-get upgrade -y --no-install-recommends \
 && echo "npm cache clean" \
 && time npm cache clean --force \
 && echo "pecl clear-cache" \
 && time pecl clear-cache \
 && echo "apt-get -q purge" \
 && time apt-get -q purge -y --auto-remove gcc libonig-dev make \
 && echo "apt-get -q clean" \
 && time apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /var/www/html/auth \
 && mkdir -p /var/www/html/phpmyadmin \
 && a2dissite -q 000-default.conf \
 && a2enmod -q authz_groupfile rewrite \
 && ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime \
 && echo "tar xf" \
 && time tar xf ./phpMyAdmin-5.2.1-all-languages.tar.xz --strip-components=1 -C /var/www/html/phpmyadmin \
 && rm ./phpMyAdmin-5.2.1-all-languages.tar.xz ./download.txt \
 && chown www-data:www-data /var/www/html/phpmyadmin -R

COPY ./config.inc.php /var/www/html/phpmyadmin/
COPY ./app/* ./
COPY --chmod=755 ./app/*.sh ./
COPY ./Dockerfile ./
COPY --from=memcached:latest /usr/local/bin/memcached ./

COPY ./auth/*.php /var/www/html/auth/

# CMD ["bash","/usr/src/app/start.sh"]
ENTRYPOINT ["bash","/usr/src/app/start.sh"]
