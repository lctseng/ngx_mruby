#!/bin/sh

# Default install
#   download nginx into ./build/
#   build into ./build/nginx

# ENV example
#
#   NGINX_CONFIG_OPT_ENV='--prefix=/usr/local/nginx-1.4.4' NGINX_SRC_ENV='/usr/local/src/nginx-1.4.4' sh build.sh
#

sudo apt install -y libgd-dev libgeoip-dev libatomic-ops-dev libperl-dev
sudo apt install -y libpcre3-dev libpcre3 bison
NGX_MRUBY_SRC=`pwd`

set -e

. ./nginx_version

# OS specific configuration
if [ `uname -s` = "NetBSD" ]; then
    NPROCESSORS_ONLN="NPROCESSORS_ONLN"
    NGINX_DEFUALT_OPT='--with-http_stub_status_module --with-stream --without-stream_access_module --with-ld-opt=-L/usr/pkg/lib\ -Wl,-R/usr/pkg/lib'
    MAKE=gmake
else
    NPROCESSORS_ONLN="_NPROCESSORS_ONLN"
    NGINX_DEFUALT_OPT='--with-http_stub_status_module --with-stream --without-stream_access_module'
    MAKE=make
fi

if [ -n "$BUILD_DYNAMIC_MODULE" ]; then
    BUILD_DIR='build_dynamic'
    NGINX_INSTALL_DIR=`pwd`'/build_dynamic/nginx'
    CONFIG_OPT="--enable-dynamic-module --with-build-dir=$BUILD_DIR"
else
    BUILD_DIR='build'
    NGINX_INSTALL_DIR=`pwd`'/build/nginx'
    CONFIG_OPT="--with-build-dir=$BUILD_DIR"
fi

if [ "$NGINX_CONFIG_OPT_ENV" != "" ]; then
    NGINX_CONFIG_OPT=$NGINX_CONFIG_OPT_ENV
else
    NGINX_CONFIG_OPT="--prefix=${NGINX_INSTALL_DIR} ${NGINX_DEFUALT_OPT}"
fi

if [ "$NUM_THREADS_ENV" != "" ]; then
    NUM_THREADS=$NUM_THREADS_ENV
else
    NUM_PROCESSORS=`getconf $NPROCESSORS_ONLN`
    if [ $NUM_PROCESSORS -gt 1 ]; then
        NUM_THREADS=$(expr $NUM_PROCESSORS / 2)
    else
        NUM_THREADS=1
    fi
fi

echo "NGINX_CONFIG_OPT=$NGINX_CONFIG_OPT"
echo "NUM_THREADS=$NUM_THREADS"

if [ $NGINX_SRC_ENV ]; then
    NGINX_SRC=$NGINX_SRC_ENV
else
    echo "nginx Downloading ..."
    if [ -d "./${BUILD_DIR}" ]; then
        echo "build directory was found"
    else
        mkdir ${BUILD_DIR}
    fi
    cd ${BUILD_DIR}
    if [ ! -e ${NGINX_SRC_VER} ]; then
        wget http://nginx.org/download/${NGINX_SRC_VER}.tar.gz
        echo "nginx Downloading ... Done"
        tar xzf ${NGINX_SRC_VER}.tar.gz
    fi
    ln -snf ${NGINX_SRC_VER} nginx_src
    NGINX_SRC=`pwd`'/nginx_src'
    cd ..
fi

# FIXME: not sure if we really need this. even if we do, it should be moved to mruby/Rakefile
if [ -d "./mruby/${BUILD_DIR}" ]; then
    echo "mruby Cleaning ..."
    (cd mruby && ./minirake clean)
    echo "mruby Cleaning ... Done"
fi

echo "ngx_mruby configure ..."
./configure --with-ngx-src-root=${NGINX_SRC} --with-ngx-config-opt="${NGINX_CONFIG_OPT}" $@
echo "ngx_mruby configure ... Done"

echo "ngx_mruby building ..."
echo `pwd`
$MAKE NUM_THREADS=$NUM_THREADS -j $NUM_THREADS
echo "ngx_mruby building ... Done"

echo "build.sh ... successful"

if [ -n "$BUILD_DYNAMIC_MODULE" ]; then
  echo "Building Dynamic.."
  cd ${NGX_MRUBY_SRC}
  ./configure --with-ngx-src-root=${NGINX_SRC}
  make generate_gems_config_dynamic
  cd ${NGINX_SRC}
  ./configure --user=nginx --group=nginx --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid   --with-select_module --with-poll_module --with-file-aio --with-ipv6 --with-http_ssl_module  --with-http_realip_module --with-http_addition_module --with-http_xslt_module --with-http_image_filter_module --with-http_geoip_module --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_auth_request_module --with-http_random_index_module --with-http_secure_link_module --with-http_degradation_module --with-http_stub_status_module --with-http_perl_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-cpp_test_module  --with-cpu-opt=CPU --with-pcre  --with-pcre-jit  --with-md5-asm  --with-sha1-asm  --with-zlib-asm=CPU --with-libatomic --with-debug --with-ld-opt="-Wl,-E" --add-dynamic-module=${NGX_MRUBY_SRC} --add-dynamic-module=${NGX_MRUBY_SRC}/dependence/ngx_devel_kit 
  make
fi
#sudo make install
