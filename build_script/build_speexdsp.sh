#!/bin/bash

#作者：康林
#参数:
#    $1:编译目标(android、windows_msvc、windows_mingw、unix)
#    $2:源码的位置 

#运行本脚本前,先运行 build_$1_envsetup.sh 进行环境变量设置,需要先设置下面变量:
#   BUILD_TARGERT   编译目标（android、windows_msvc、windows_mingw、unix）
#   RABBIT_BUILD_PREFIX=`pwd`/../${BUILD_TARGERT}  #修改这里为安装前缀
#   RABBIT_BUILD_SOURCE_CODE    #源码目录
#   RABBIT_BUILD_CROSS_PREFIX   #交叉编译前缀
#   RABBIT_BUILD_CROSS_SYSROOT  #交叉编译平台的 sysroot

set -e
HELP_STRING="Usage $0 PLATFORM(android|windows_msvc|windows_mingw|unix) [SOURCE_CODE_ROOT_DIRECTORY]"

case $1 in
    android|windows_msvc|windows_mingw|unix)
    BUILD_TARGERT=$1
    ;;
    *)
    echo "${HELP_STRING}"
    exit 1
    ;;
esac

RABBIT_BUILD_SOURCE_CODE=$2

echo ". `pwd`/build_envsetup_${BUILD_TARGERT}.sh"
. `pwd`/build_envsetup_${BUILD_TARGERT}.sh

if [ -z "$RABBIT_BUILD_SOURCE_CODE" ]; then
    RABBIT_BUILD_SOURCE_CODE=${RABBIT_BUILD_PREFIX}/../src/speexdsp
fi

CUR_DIR=`pwd`

#下载源码:
if [ ! -d ${RABBIT_BUILD_SOURCE_CODE} ]; then
    SPEEXDSP_VERSION=master
    if [ "TRUE" = "${RABBIT_USE_REPOSITORIES}" ]; then
        #echo "git clone --branch=SpeexDSP-${SPEEXDSP_VERSION} http://git.xiph.org/speexdsp.git  ${RABBIT_BUILD_SOURCE_CODE}"
        #git clone -q --branch=SpeexDSP-${SPEEXDSP_VERSION} http://git.xiph.org/speexdsp.git ${RABBIT_BUILD_SOURCE_CODE}
        echo "git clone https://github.com/KangLin/speexdsp.git ${RABBIT_BUILD_SOURCE_CODE}"
        git clone -q https://github.com/KangLin/speexdsp.git ${RABBIT_BUILD_SOURCE_CODE}
    else
        mkdir -p ${RABBIT_BUILD_SOURCE_CODE}
        cd ${RABBIT_BUILD_SOURCE_CODE}
        echo "wget -q https://github.com/KangLin/speexdsp/archive/master.zip"
        wget -q https://github.com/KangLin/speexdsp/archive/master.tar.gz
        tar xzf master.tar.gz
        
        #echo "wget -q http://downloads.xiph.org/releases/speex/speexdsp-${SPEEXDSP_VERSION}.tar.gz"
        #wget -q -c http://downloads.xiph.org/releases/speex/speexdsp-${SPEEXDSP_VERSION}.tar.gz
        #tar xzf speexdsp-${SPEEXDSP_VERSION}.tar.gz
        
        mv speexdsp-${SPEEXDSP_VERSION} ..
        rm -fr *
        cd ..
        rm -fr ${RABBIT_BUILD_SOURCE_CODE}
        mv -f speexdsp-${SPEEXDSP_VERSION} ${RABBIT_BUILD_SOURCE_CODE}
    fi
fi

cd ${RABBIT_BUILD_SOURCE_CODE}

if [ ! -f configure -a "${BUILD_TARGERT}" != "windows_msvc" ]; then
    echo "sh autogen.sh"
    sh autogen.sh
fi

mkdir -p build_${BUILD_TARGERT}
cd build_${BUILD_TARGERT}
if [ "$RABBIT_CLEAN" = "TRUE" ]; then
    rm -fr *
fi

echo ""
echo "BUILD_TARGERT:${BUILD_TARGERT}"
echo "RABBIT_BUILD_SOURCE_CODE:$RABBIT_BUILD_SOURCE_CODE"
echo "CUR_DIR:`pwd`"
echo "RABBIT_BUILD_PREFIX:$RABBIT_BUILD_PREFIX"
echo "RABBIT_BUILD_HOST:$RABBIT_BUILD_HOST"
echo "RABBIT_BUILD_CROSS_HOST:$RABBIT_BUILD_CROSS_HOST"
echo "RABBIT_BUILD_CROSS_PREFIX:$RABBIT_BUILD_CROSS_PREFIX"
echo "RABBIT_BUILD_CROSS_SYSROOT:$RABBIT_BUILD_CROSS_SYSROOT"
echo "RABBIT_BUILD_STATIC:$RABBIT_BUILD_STATIC"
echo ""

echo "configure ..."

if [ "$RABBIT_BUILD_STATIC" = "static" ]; then
    CONFIG_PARA="--enable-static --disable-shared"
else
    CONFIG_PARA="--disable-static --enable-shared"
fi
case ${BUILD_TARGERT} in
    android)
        CONFIG_PARA="${CONFIG_PARA} --host=$RABBIT_BUILD_CROSS_HOST"
        #CONFIG_PARA="${CONFIG_PARA} --with-sysroot=${RABBIT_BUILD_CROSS_SYSROOT}"
        CFLAGS="${RABBIT_CFLAGS}"
        CPPFLAGS="${RABBIT_CPPFLAGS}"
        LDFLAGS="${RABBIT_LDFLAGS}"
        ;;
    unix)
        CONFIG_PARA="${CONFIG_PARA} --enable-vbr --enable-sse"
        ;;
    windows_msvc)
        cd ${RABBIT_BUILD_SOURCE_CODE}
        if [ -d ".git" ]; then
            git clean -xdf
        fi
        
        if [ "Debug" = "$RABBIT_CONFIG" ]; then
            Configuration=Debug
        else
            Configuration=Release
        fi
        if [  "$TOOLCHAIN_VERSION" = "15" ]; then
    
            if [ "$BUILD_ARCH" = "x64" ]; then
                msbuild.exe -m -v:n -p:Configuration=${Configuration} -p:Platform=x64 win32/VS2008/libspeexdsp.sln
            else
                msbuild.exe -m -v:n -p:Configuration=${Configuration} -p:Platform=Win32 win32/VS2008/libspeexdsp.sln
            fi
        fi
        
        if [  "$TOOLCHAIN_VERSION" = "12" ]; then
            if [ "$BUILD_ARCH" = "x64" ]; then
                msbuild.exe -m -v:n -p:Configuration=${Configuration} -p:Platform=x64 win32/VS2008/libspeexdsp.sln
            else
                msbuild.exe -m -v:n -p:Configuration=${Configuration} -p:Platform=Win32 win32/VS2008/libspeexdsp.sln
            fi
        fi
        
        if [  "$TOOLCHAIN_VERSION" = "14" ]; then
            if [ "$BUILD_ARCH" = "x64" ]; then
                msbuild.exe -m -v:n -p:Configuration=${Configuration} -p:Platform=x64 win32/VS2008/libspeexdsp.sln
            else
                msbuild.exe -m -v:n -p:Configuration=${Configuration} -p:Platform=Win32 win32/VS2008/libspeexdsp.sln
            fi
        fi
        cp lib/libspeexdsp.lib $RABBIT_BUILD_PREFIX/lib/libspeexdsp.lib
        cd $CUR_DIR
        exit 0
        ;;
    windows_mingw)
        CONFIG_PARA="${CONFIG_PARA} --host=$RABBIT_BUILD_CROSS_HOST"
        #CONFIG_PARA="${CONFIG_PARA} --with-sysroot=${RABBIT_BUILD_CROSS_SYSROOT}"
        CFLAGS="${RABBIT_CFLAGS}"
        CPPFLAGS="${RABBIT_CPPFLAGS}"
        LDFLAGS="${RABBIT_LDFLAGS}"
        CONFIG_PARA="${CONFIG_PARA} --enable-sse"
        ;;
    *)
        echo "${HELP_STRING}"
        cd $CUR_DIR
        exit 3
        ;;
esac

CONFIG_PARA="${CONFIG_PARA} --disable-examples"
CONFIG_PARA="${CONFIG_PARA} --prefix=$RABBIT_BUILD_PREFIX"
echo "../configure ${CONFIG_PARA} CFLAGS=\"${CFLAGS=}\" CPPFLAGS=\"${CPPFLAGS}\" CXXFLAGS=\"${CPPFLAGS}\" LDFLAGS=\"${LDFLAGS}\""
../configure ${CONFIG_PARA} \
    CFLAGS="${CFLAGS}" \
    CPPFLAGS="${CPPFLAGS}" \
    CXXFLAGS="${CPPFLAGS}" \
    LDFLAGS="${LDFLAGS}"

echo "make install"
$MAKE ${BUILD_JOB_PARA} 
$MAKE install

cd $CUR_DIR
