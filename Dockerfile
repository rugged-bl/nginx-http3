# https://hg.nginx.org/nginx/file/tip/src/core/nginx.h
ARG NGINX_VERSION=1.27.3

# https://github.com/google/ngx_brotli
ARG NGX_BROTLI_COMMIT=a71f9312c2deb28875acc7bacfdd5695a111aa53

# https://github.com/openssl/openssl
ARG OPENSSL_VERSION=3.4.0

# NGINX UID / GID
ARG NGINX_USER_UID=100
ARG NGINX_GROUP_GID=101

# https://nginx.org/en/docs/http/ngx_http_v3_module.html
# https://nginx.org/en/docs/configure.html
ARG CONFIG="\
    --build=$NGINX_VERSION \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx/nginx.pid \
    --lock-path=/var/run/nginx/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --user=nginx \
    --group=nginx \
    --with-cc=gcc \
    --without-http_fastcgi_module \
    --without-http_uwsgi_module \
    --without-http_scgi_module \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-openssl=/usr/src/openssl-$OPENSSL_VERSION \
    --add-module=/usr/src/ngx_brotli \
"

FROM alpine:3.20 AS base

ARG NGINX_VERSION
ARG NGX_BROTLI_COMMIT
ARG OPENSSL_VERSION
ARG NGINX_USER_UID
ARG NGINX_GROUP_GID
ARG CONFIG

RUN \
    apk add --no-cache --virtual .build-deps \
        gcc \
        gd-dev \
        gnupg \
        go \
        libc-dev \
        linux-headers \
        make \
        musl-dev \
        ninja \
        pcre-dev \
        zlib-dev \
        autoconf \
        automake \
        cmake \
        g++ \
        git \
        libtool \
   && git config --global init.defaultBranch master

WORKDIR /usr/src/

RUN \
    echo "Cloning nginx $NGINX_VERSION ..." \
    && git clone --branch release-${NGINX_VERSION} --depth 1 https://github.com/nginx/nginx.git /usr/src/nginx-$NGINX_VERSION

RUN \
    echo "Cloning brotli $NGX_BROTLI_COMMIT ..." \
    && mkdir /usr/src/ngx_brotli \
    && cd /usr/src/ngx_brotli \
    && git init \
    && git remote add origin https://github.com/google/ngx_brotli.git \
    && git fetch --depth 1 origin $NGX_BROTLI_COMMIT \
    && git checkout --recurse-submodules -q FETCH_HEAD \
    && git submodule update --init --depth 1

# https://www.f5.com/company/blog/nginx/quic-http3-support-openssl-nginx
RUN \
    echo "Cloning OpenSSL $OPENSSL_VERSION ..." \
    &&git clone --depth 1 --branch openssl-$OPENSSL_VERSION https://github.com/openssl/openssl.git /usr/src/openssl-$OPENSSL_VERSION

ARG CC_OPT='-O2 -flto=auto -ffat-lto-objects -flto=auto -ffat-lto-objects -fstack-protector-strong -Wformat -Werror=format-security -fPIC -Wdate-time -D_FORTIFY_SOURCE=2'
ARG LD_OPT='-Wl,-Bsymbolic-functions -flto=auto -ffat-lto-objects -flto=auto -Wl,-z,relro -Wl,-z,now -fPIC'
RUN \
    echo "Building nginx ..." \
    && mkdir -p /var/run/nginx/ \
    && cd /usr/src/nginx-$NGINX_VERSION \
    && ./auto/configure $CONFIG --with-cc-opt="$CC_OPT" --with-ld-opt="$LD_OPT" \
    && make -j"$(getconf _NPROCESSORS_ONLN)"

RUN \
    cd /usr/src/nginx-$NGINX_VERSION \
    && make install \
    && rm -rf /etc/nginx/html/ \
    && mkdir /etc/nginx/conf.d/ \
    && strip /usr/sbin/nginx* \
    \
    && scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so \
         | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
         | sort -u \
         | xargs -r apk info --installed \
         | sort -u > /tmp/nginx-runDeps.txt

FROM alpine:3.20
ARG NGINX_VERSION
ARG NGINX_USER_UID
ARG NGINX_GROUP_GID

ENV NGINX_VERSION=$NGINX_VERSION

COPY --from=base /var/run/nginx/ /var/run/nginx/
COPY --from=base /etc/nginx /etc/nginx
COPY --from=base /usr/sbin/nginx /usr/sbin/
COPY --from=base /tmp/nginx-runDeps.txt /tmp/nginx-runDeps.txt

RUN \
    addgroup --gid $NGINX_GROUP_GID -S nginx \
    && adduser --uid $NGINX_USER_UID -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
    && apk add --no-cache --virtual .nginx-rundeps tzdata $(cat /tmp/nginx-runDeps.txt) \
    && rm /tmp/nginx-runDeps.txt \
    && ln -s /usr/lib/nginx/modules /etc/nginx/modules \
    # forward request and error logs to docker log collector
    && mkdir /var/log/nginx \
    && touch /var/log/nginx/access.log /var/log/nginx/error.log \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

# uncomment to show the configuration
#RUN nginx -V

EXPOSE 80 443/udp 443/tcp

STOPSIGNAL SIGTERM

# prepare to switching to non-root - update file permissions of directory containing
# nginx.lock and nginx.pid file
RUN \
    chown -R --verbose nginx:nginx \
      /var/run/nginx/

USER nginx
CMD ["nginx", "-g", "daemon off;"]
