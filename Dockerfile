FROM php:8.3-apache

EXPOSE 80

SHELL ["/bin/bash", "-c"]

WORKDIR /usr/src/app

ENV CFLAGS="-O2 -march=native -mtune=native -fomit-frame-pointer"
ENV CXXFLAGS="$CFLAGS"
ENV LDFLAGS="-fuse-ld=gold"
ENV NODE_ENV=production
ENV NODE_MAJOR=20

COPY ./php.ini ${PHP_INI_DIR}/
COPY --chmod=644 .htpasswd /var/www/html/
COPY ./apache.conf /etc/apache2/sites-enabled/
COPY ./app/*.json ./

ENV SQLITE_JDBC_VERSION="3.44.1.0"

# https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.tar.xz
# https://repo1.maven.org/maven2/org/slf4j/slf4j-api/2.0.9/slf4j-api-2.0.9.jar
# https://repo1.maven.org/maven2/org/slf4j/slf4j-nop/2.0.9/slf4j-nop-2.0.9.jar

# binutils : strings
# ca-certificates : node.js
# curl : node.js
# default-jre-headless : java
# iproute2 : ss
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
RUN set -x \
 && savedAptMark="$(apt-mark showmanual)" \
 && { \
  echo "https://github.com/xerial/sqlite-jdbc/releases/download/$SQLITE_JDBC_VERSION/sqlite-jdbc-$SQLITE_JDBC_VERSION.jar"; \
  echo "https://raw.githubusercontent.com/tshr20180821/render-07/main/app/phpMyAdmin-5.2.1-all-languages.tar.xz"; \
  echo "https://raw.githubusercontent.com/tshr20180821/render-07/main/app/slf4j-api-2.0.9.jar"; \
  echo "https://raw.githubusercontent.com/tshr20180821/render-07/main/app/slf4j-nop-2.0.9.jar"; \
  echo "https://raw.githubusercontent.com/tshr20180821/render-07/main/app/LogOperation.jar"; \
  echo "https://raw.githubusercontent.com/tshr20180821/render-07/main/app/gpg"; \
  echo "http://mirror.coganng.com/debian/pool/main/a/apache2/apache2_2.4.58-1_amd64.deb"; \
  echo "http://mirror.coganng.com/debian/pool/main/a/apache2/apache2-bin_2.4.58-1_amd64.deb"; \
  echo "http://mirror.coganng.com/debian/pool/main/a/apache2/apache2-data_2.4.58-1_all.deb"; \
  echo "http://mirror.coganng.com/debian/pool/main/a/apache2/apache2-utils_2.4.58-1_amd64.deb"; \
  } >download.txt \
 && time xargs -P2 -n1 curl -sSLO <download.txt \
 && chmod +x ./gpg \
 && mkdir -p /etc/apt/keyrings \
 && curl -fsSL 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xA2166B8DE8BDC3367D1901C11EE2FF37CA8DA16B' | ./gpg --dearmor -o /etc/apt/keyrings/apt-fast.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/apt-fast.gpg] http://ppa.launchpad.net/apt-fast/stable/ubuntu jammy main" | tee /etc/apt/sources.list.d/apt-fast.list \
 && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | ./gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
 && echo "deb http://deb.debian.org/debian bookworm-backports main contrib non-free" | tee /etc/apt/sources.list.d/backports.list \
 && time apt-get -q update \
 && time DEBIAN_FRONTEND=noninteractive apt-get -q install -y --no-install-recommends \
  apt-fast \
  curl/bookworm-backports \
 && echo "MIRRORS=( 'http://deb.debian.org/debian, http://cdn-fastly.deb.debian.org/debian, http://httpredir.debian.org/debian' )" >/etc/apt-fast.conf \
 && time apt-fast install -y --no-install-recommends \
  binutils \
  ca-certificates \
  curl \
  default-jre-headless \
  iproute2 \
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
 && time dpkg -i \
  apache2-bin_2.4.58-1_amd64.deb \
  apache2-data_2.4.58-1_all.deb \
  apache2-utils_2.4.58-1_amd64.deb \
  apache2_2.4.58-1_amd64.deb \
 && rm -f *.deb \
 && time MAKEFLAGS="-j $(nproc)" pecl install apcu >/dev/null \
 && time MAKEFLAGS="-j $(nproc)" pecl install memcached --enable-memcached-sasl >/dev/null \
 && time docker-php-ext-enable \
  apcu \
  memcached \
 && time docker-php-ext-configure zip --with-zip >/dev/null \
 && time docker-php-ext-install -j$(nproc) \
  pdo_mysql \
  mysqli \
  mbstring \
  opcache \
  >/dev/null \
 && time npm install \
 && time npm update -g \
 && time npm audit fix \
 && time apt-get upgrade -y --no-install-recommends \
 && time npm cache clean --force \
 && time pecl clear-cache \
 && time apt-get -q purge -y --auto-remove \
  gcc \
  libonig-dev \
  make \
  re2c \
 && dpkg -l >./package_list_before.txt \
 && time apt-mark auto '.*' >/dev/null \
 && time apt-mark manual ${savedAptMark} >/dev/null \
 && time find /usr/local -type f -executable -exec ldd '{}' ';' | \
  awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); print so }' | \
  sort -u | xargs -r dpkg-query --search | cut -d: -f1 | sort -u | xargs -r apt-mark manual >/dev/null 2>&1 \
 && apt-mark manual \
  default-jre-headless \
  iproute2 \
  libmemcached-dev \
  libsasl2-modules \
  memcached \
  nodejs \
  sasl2-bin \
 && time apt-mark showmanual \
 && time apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
 && dpkg -l >./package_list_after.txt \
 && diff -u ./package_list_before.txt ./package_list_after.txt | cat \
 && time apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /var/www/html/auth \
 && mkdir -p /var/www/html/phpmyadmin \
 && a2dissite -q 000-default.conf \
 && a2enmod -q authz_groupfile rewrite \
 && ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime \
 && time tar xf ./phpMyAdmin-5.2.1-all-languages.tar.xz --strip-components=1 -C /var/www/html/phpmyadmin \
 && rm ./phpMyAdmin-5.2.1-all-languages.tar.xz ./download.txt ./gpg ./package_list_before.txt ./package_list_after.txt \
 && chown www-data:www-data /var/www/html/phpmyadmin -R \
 && echo '<HTML />' >/var/www/html/index.html \
 && { \
  echo 'User-agent: *'; \
  echo 'Disallow: /'; \
  } >/var/www/html/robots.txt

COPY ./config.inc.php /var/www/html/phpmyadmin/
COPY ./Dockerfile ./app/*.js ./app/*.php ./
COPY --chmod=755 ./app/*.sh ./
COPY --from=memcached:latest /usr/local/bin/memcached /usr/bin/

COPY ./auth/*.php /var/www/html/auth/

STOPSIGNAL SIGWINCH

# CMD ["bash","/usr/src/app/start.sh"]
ENTRYPOINT ["/bin/bash","/usr/src/app/start.sh"]
