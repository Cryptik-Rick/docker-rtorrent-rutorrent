ARG ALPINE_VERSION=3.19
ARG LIBSIG_VERSION=3.0.7
ARG CARES_VERSION=1.23.0
ARG CURL_VERSION=8.5.0
ARG GEOIP2_PHPEXT_VERSION=1.3.1
ARG XMLRPC_VERSION=01.60.00
ARG LIBTORRENT_VERSION=0.13.8
ARG RTORRENT_VERSION=0.9.8

# v4.3.3
ARG RUTORRENT_VERSION=fa4e4e29c4d0fe89faac960a56a0e00175ba75f9
ARG GEOIP2_RUTORRENT_VERSION=4ff2bde530bb8eef13af84e4413cedea97eda148

ENV DIST_PATH="/dist"

ARG ALPINE_VERSION=3.19
ARG ALPINE_S6_VERSION=${ALPINE_VERSION}-2.2.0.3

FROM --platform=${BUILDPLATFORM} alpine:${ALPINE_VERSION} AS src
RUN apk --update --no-cache add curl git tar tree xz
WORKDIR /src

FROM src AS src-libsig
ARG LIBSIG_VERSION
RUN curl -sSL "https://download.gnome.org/sources/libsigc%2B%2B/3.0/libsigc%2B%2B-${LIBSIG_VERSION}.tar.xz" | tar xJv --strip 1

FROM src AS src-cares
ARG CARES_VERSION
RUN curl -sSL "https://github.com/c-ares/c-ares/releases/download/cares-${CARES_VERSION//\./\_}/c-ares-${CARES_VERSION}.tar.gz" | tar xz --strip 1

FROM src AS src-xmlrpc
RUN git init . && git remote add origin "https://github.com/crazy-max/xmlrpc-c.git"
ARG XMLRPC_VERSION
RUN git fetch origin "${XMLRPC_VERSION}" && git checkout -q FETCH_HEAD

FROM src AS src-curl
ARG CURL_VERSION
RUN curl -sSL "https://curl.se/download/curl-${CURL_VERSION}.tar.gz" | tar xz --strip 1

FROM src AS src-rtorrent
RUN git init . && git remote add origin "https://github.com/stickz/rtorrent.git"
ARG RTORRENT_STICKZ_VERSION
RUN git fetch origin "${RTORRENT_STICKZ_VERSION}" && git checkout -q FETCH_HEAD

FROM src AS src-mktorrent
RUN git init . && git remote add origin "https://github.com/esmil/mktorrent.git"
ARG MKTORRENT_VERSION
RUN git fetch origin "${MKTORRENT_VERSION}" && git checkout -q FETCH_HEAD

FROM src AS src-geoip2-phpext
RUN git init . && git remote add origin "https://github.com/rlerdorf/geoip.git"
ARG GEOIP2_PHPEXT_VERSION
RUN git fetch origin "${GEOIP2_PHPEXT_VERSION}" && git checkout -q FETCH_HEAD

FROM src AS src-rutorrent
RUN git init . && git remote add origin "https://github.com/Novik/ruTorrent.git"
ARG RUTORRENT_VERSION
RUN git fetch origin "${RUTORRENT_VERSION}" && git checkout -q FETCH_HEAD
RUN rm -rf .git* conf/users plugins/geoip share

FROM src AS src-geoip2-rutorrent
RUN git init . && git remote add origin "https://github.com/Micdu70/geoip2-rutorrent.git"
ARG GEOIP2_RUTORRENT_VERSION
RUN git fetch origin "${GEOIP2_RUTORRENT_VERSION}" && git checkout -q FETCH_HEAD
RUN rm -rf .git*

FROM src AS src-mmdb
RUN curl -SsOL "https://github.com/crazy-max/geoip-updater/raw/mmdb/GeoLite2-City.mmdb" \
  && curl -SsOL "https://github.com/crazy-max/geoip-updater/raw/mmdb/GeoLite2-Country.mmdb"

FROM crazymax/alpine-s6:${ALPINE_S6_VERSION} AS builder
RUN apk --update --no-cache add \
    autoconf \
    automake \
    binutils \
    brotli-dev \
    build-base \
    curl \
    cppunit-dev \
    fftw-dev \
    gd-dev \
    geoip-dev \
    git \
    libnl3 \
    libnl3-dev \
    libtool \
    libxslt-dev \
    linux-headers \
    ncurses-dev \
    nghttp2-dev \
    openssl-dev \
    pcre-dev \
    php83-dev \
    php83-pear \
    subversion \
    tar \
    tree \
    xz \
    zlib-dev

ARG LIBSIG_VERSION
WORKDIR /tmp/libsig
RUN curl -sSL "http://ftp.gnome.org/pub/GNOME/sources/libsigc++/3.0/libsigc++-${LIBSIG_VERSION}.tar.xz" | tar -xJ --strip 1
RUN ./autogen.sh --prefix=/usr/local
RUN make -j $(nproc)
RUN make install -j $(nproc)
RUN make DESTDIR=${DIST_PATH} install -j $(nproc)

ARG CARES_VERSION
WORKDIR /tmp/cares
RUN curl -sSL "https://c-ares.org/download/c-ares-${CARES_VERSION}.tar.gz" | tar -xz --strip 1
RUN ./configure
RUN make -j $(nproc) CFLAGS="-O2 -flto"
RUN make install -j $(nproc)
RUN make DESTDIR=${DIST_PATH} install -j $(nproc)

ARG CURL_VERSION
WORKDIR /tmp/curl
RUN curl -sSL "https://curl.se/download/curl-${CURL_VERSION}.tar.gz" | tar -xz --strip 1
RUN ./configure \
  --enable-ares \
  --enable-tls-srp \
  --enable-gnu-tls \
  --with-brotli \
  --with-ssl \
  --with-zlib
RUN make -j $(nproc) CFLAGS="-O2 -flto -pipe"
RUN make install -j $(nproc)
RUN make DESTDIR=${DIST_PATH} install -j $(nproc)

ARG GEOIP2_PHPEXT_VERSION
WORKDIR /tmp/geoip2-phpext
RUN git clone -q "https://github.com/rlerdorf/geoip" . && git reset --hard ${GEOIP2_PHPEXT_VERSION} && rm -rf .git
RUN set -e
RUN phpize83
RUN ./configure --with-php-config=/usr/bin/php-config83
RUN make -j $(nproc)
RUN make install -j $(nproc)
RUN make DESTDIR=${DIST_PATH} install -j $(nproc)

ARG XMLRPC_VERSION
WORKDIR /tmp/xmlrpc-c
RUN svn checkout -q "http://svn.code.sf.net/p/xmlrpc-c/code/release_number/${XMLRPC_VERSION}/" . && rm -rf .svn
RUN ./configure \
   --disable-wininet-client \
   --disable-libwww-client
RUN make -j $(nproc) CXXFLAGS="-flto"
RUN make install -j $(nproc)
RUN make DESTDIR=${DIST_PATH} install -j $(nproc)
RUN mkdir -p ${DIST_PATH}/usr/lib/php83/modules
RUN cp -f /usr/lib/php83/modules/geoip.so ${DIST_PATH}/usr/lib/php83/modules/

ARG LIBTORRENT_VERSION
WORKDIR /tmp/libtorrent
RUN git clone -q "https://github.com/rakshasa/libtorrent" . && git reset --hard v${LIBTORRENT_VERSION} && rm -rf .git
RUN ./autogen.sh
RUN ./configure \
  --with-posix-fallocate
RUN make -j $(nproc) CXXFLAGS="-O2 -flto"
RUN make install -j $(nproc)
RUN make DESTDIR=${DIST_PATH} install -j $(nproc)

ARG RTORRENT_VERSION
WORKDIR /tmp/rtorrent
RUN git clone -q "https://github.com/rakshasa/rtorrent" . && git reset --hard v${RTORRENT_VERSION} && rm -rf .git
RUN ./autogen.sh
RUN ./configure \
  --with-xmlrpc-c \
  --with-ncurses
RUN make -j $(nproc) CXXFLAGS="-O2 -flto"
RUN make install -j $(nproc)
RUN make DESTDIR=${DIST_PATH} install -j $(nproc)

ARG ALPINE_VERSION
FROM alpine:${ALPINE_VERSION} AS download

RUN apk --update --no-cache add curl git tar xz

ARG RUTORRENT_REVISION
WORKDIR /dist/rutorrent
RUN git clone -q "https://github.com/Novik/ruTorrent" . && git reset --hard ${RUTORRENT_REVISION} && rm -rf .git
RUN rm -rf conf/users plugins/geoip plugins/_cloudflare share

WORKDIR /dist/rutorrent-geoip2
RUN git clone -q "https://github.com/Micdu70/geoip2-rutorrent" . && rm -rf .git

WORKDIR /dist/rutorrent-filemanager
RUN git clone -q "https://github.com/nelu/rutorrent-filemanager" . 

WORKDIR /dist/rutorrent-ratio
RUN git clone -q "https://github.com/Gyran/rutorrent-ratiocolor" . && rm -rf .git

WORKDIR /dist/rutorrent-theme-quick
RUN git clone -q "https://github.com/TrimmingFool/club-QuickBox" . && rm -rf .git

WORKDIR /dist/rutorrent-theme-rtmodern-remix
RUN git clone -q "https://github.com/Teal-c/rtModern-Remix" . && rm -rf .git \
    && cp -ar /dist/rutorrent-theme-rtmodern-remix /dist/rutorrent-theme-rtmodern-remix-plex \
    && cat themes/plex.css > custom.css \
    && cp -ar /dist/rutorrent-theme-rtmodern-remix /dist/rutorrent-theme-rtmodern-remix-jellyfin \
    && cat themes/jellyfin.css > custom.css \
    && cp -ar /dist/rutorrent-theme-rtmodern-remix /dist/rutorrent-theme-rtmodern-remix-jellyfin-bg \
    && cat themes/jellyfin-bg.css > custom.css \
    && cp -ar /dist/rutorrent-theme-rtmodern-remix /dist/rutorrent-theme-rtmodern-remix-lightpink \
    && cat themes/light-pink.css > custom.css

WORKDIR /dist/mmdb
RUN curl -SsOL "https://github.com/crazy-max/geoip-updater/raw/mmdb/GeoLite2-City.mmdb"
RUN curl -SsOL "https://github.com/crazy-max/geoip-updater/raw/mmdb/GeoLite2-Country.mmdb"

ARG ALPINE_VERSION
FROM alpine:${ALPINE_VERSION} as builder

ENV PYTHONPATH="$PYTHONPATH:/var/www/rutorrent" \
  S6_BEHAVIOUR_IF_STAGE2_FAILS="2" \
  S6_KILL_GRACETIME="5000" \
  TZ="UTC" \
  PUID="1000" \
  PGID="1000"

RUN apk --update --no-cache add unrar --repository=http://dl-cdn.alpinelinux.org/alpine/v3.14/main
RUN apk --update --no-cache add \
    apache2-utils \
    bash \
    bind-tools \
    binutils \
    brotli \
    ca-certificates \
    coreutils \
    cppunit-dev \
    dhclient \
    ffmpeg \
    findutils \
    geoip \
    grep \
    gzip \
    htop \
    libstdc++ \
    mediainfo \
    nano \
    ncurses \
    nginx \
    nginx-mod-http-brotli \
    nginx-mod-http-headers-more \
    nginx-mod-http-dav-ext \
    nginx-mod-http-geoip2 \
    mktorrent \
    openssl \
    pcre \
    php83 \
    php83-bcmath \
    php83-cli \
    php83-ctype \
    php83-curl \
    php83-dom \
    php83-fpm \
    php83-json \
    php83-mbstring \
    php83-openssl \
    php83-opcache \
    php83-pecl-apcu \
    php83-pear \
    php83-phar \
    php83-posix \
    php83-session \
    php83-sockets \
    php83-xml \
    php83-zip \
    php83-zlib \
    python3 \
    py3-pip \
    p7zip \
    s6-overlay \
    shadow \
    sox \
    tar \
    tzdata \
    unzip \
    util-linux \
    zip \
    zlib \
  && addgroup -g ${PGID} rtorrent \
  && adduser -D -H -u ${PUID} -G rtorrent -s /bin/sh rtorrent \
  && rm -rf /tmp/* /var/cache/apk/*

RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    ln -sf /dev/stdout /var/log/php83/access.log && \
    ln -sf /dev/stderr /var/log/php83/error.log

COPY rootfs /
COPY --from=compile /dist /
COPY --from=download /dist/mmdb /var/mmdb
COPY --from=download --chown=nobody:nogroup /dist/rutorrent /var/www/rutorrent
COPY --from=download --chown=nobody:nogroup /dist/rutorrent-geoip2 /var/www/rutorrent/plugins/geoip2
COPY --from=download --chown=nobody:nogroup /dist/rutorrent-filemanager /var/www/rutorrent/plugins/filemanager
COPY --from=download --chown=nobody:nogroup /dist/rutorrent-ratio /var/www/rutorrent/plugins/ratiocolor
COPY --from=download --chown=nobody:nogroup /dist/rutorrent-theme-quick /var/www/rutorrent/plugins/theme/themes/QuickBox
COPY --from=download --chown=nobody:nogroup /dist/rutorrent-theme-rtmodern-remix /var/www/rutorrent/plugins/theme/themes/Remix
COPY --from=download --chown=nobody:nogroup /dist/rutorrent-theme-rtmodern-remix-plex /var/www/rutorrent/plugins/theme/themes/Plex
COPY --from=download --chown=nobody:nogroup /dist/rutorrent-theme-rtmodern-remix-jellyfin /var/www/rutorrent/plugins/theme/themes/Jellyfin
COPY --from=download --chown=nobody:nogroup /dist/rutorrent-theme-rtmodern-remix-jellyfin-bg /var/www/rutorrent/plugins/theme/themes/Jellyfin-bg
COPY --from=download --chown=nobody:nogroup /dist/rutorrent-theme-rtmodern-remix-lightpink /var/www/rutorrent/plugins/theme/themes/LightPink

VOLUME [ "/config", "/data", "/passwd" ]

ENTRYPOINT [ "/init" ]

HEALTHCHECK --interval=30s --timeout=20s --start-period=10s \
  CMD /usr/local/bin/healthcheck
