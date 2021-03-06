#!/bin/bash
set -e

RABBIT_LIBRARYS_before[0]="zlib"
RABBIT_LIBRARYS_backgroud[0]="protobuf libpng jpeg libyuv libvpx libopus speexdsp speex libqrencode"
RABBIT_LIBRARYS[0]="change_prefix openssl ffmpeg"
RABBIT_LIBRARYS_backgroud[1]="dlib ncnn seeta libfacedetection"
RABBIT_LIBRARYS[1]="opencv"
RABBIT_LIBRARYS[2]="qxmpp qzxing"

SOURCE_DIR=$(cd `dirname $0`; pwd)/../..
if [ -n "$1" ]; then
    SOURCE_DIR=$1
fi
TOOLS_DIR=${SOURCE_DIR}/Tools
export RABBIT_BUILD_PREFIX=${SOURCE_DIR}/build_${BUILD_TARGERT}

function version_gt() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"; }
function version_le() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" == "$1"; }
function version_lt() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1"; }
function version_ge() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"; }

cd ${SOURCE_DIR}

# 解压上一步编译的库
if [ -f "build_${BUILD_TARGERT}.zip" ]; then
    unzip -q "build_${BUILD_TARGERT}.zip" -d ${RABBIT_BUILD_PREFIX}
fi

if [ "$BUILD_TARGERT" = "android" ]; then
    export ANDROID_SDK_ROOT=${TOOLS_DIR}/android-sdk
    export ANDROID_NDK_ROOT=${TOOLS_DIR}/android-ndk
    #if [ -n "$APPVEYOR" ]; then
        #export JAVA_HOME="/C/Program Files (x86)/Java/jdk1.8.0"
    #    export ANDROID_NDK_ROOT=${TOOLS_DIR}/android-sdk/ndk-bundle
    #fi
    #if [ "$TRAVIS" = "true" ]; then
        #export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
    #fi
    if [ -d ${TOOLS_DIR}/android-studio/jre ]; then
        export JAVA_HOME=${TOOLS_DIR}/android-studio/jre
    fi
    
    if version_ge $QT_VERSION_DIR 5.14 ; then
        if [ -d ${TOOLS_DIR}/Qt/${QT_VERSION}/${QT_VERSION}/android ]; then
            export QT_ROOT=${TOOLS_DIR}/Qt/${QT_VERSION}/${QT_VERSION}/android
        fi
    else
        case $BUILD_ARCH in
            arm)
                QT_ROOT=${TOOLS_DIR}/Qt/${QT_VERSION}/${QT_VERSION}/android_armv7
                ;;
            arm64)
                QT_ROOT=${TOOLS_DIR}/Qt/${QT_VERSION}/${QT_VERSION}/android_arm64_v8a
                ;;
            x86)
                QT_ROOT=${TOOLS_DIR}/Qt/${QT_VERSION}/${QT_VERSION}/android_x86
                ;;
            x86_64)
                QT_ROOT=${TOOLS_DIR}/Qt/${QT_VERSION}/${QT_VERSION}/android_x86_64
                ;;
        esac
        if [ -d ${QT_ROOT} ]; then
            export QT_ROOT=${QT_ROOT}
        fi
    fi
    #export PATH=${TOOLS_DIR}/apache-ant/bin
    export PATH=$JAVA_HOME/bin:$PATH
    export ANDROID_SDK=${ANDROID_SDK_ROOT}
    export ANDROID_NDK=${ANDROID_NDK_ROOT}
fi

TARGET_OS=`uname -s`
case $TARGET_OS in
    MINGW* | CYGWIN* | MSYS*)
        export PKG_CONFIG=/c/msys64/mingw32/bin/pkg-config.exe
        RABBIT_BUILD_HOST="windows"
        if [ "$BUILD_TARGERT" = "android" ]; then
            ANDROID_NDK_HOST=windows-x86_64
            if [ ! -d $ANDROID_NDK/prebuilt/${ANDROID_NDK_HOST} ]; then
                ANDROID_NDK_HOST=windows
            fi
            CONFIG_PARA="${CONFIG_PARA} -DCMAKE_MAKE_PROGRAM=make" #${ANDROID_NDK}/prebuilt/${ANDROID_NDK_HOST}/bin/make.exe"
        fi
        ;;
    Linux* | Unix*)
    ;;
    *)
    ;;
esac

if [ "${BUILD_TARGERT}" = "unix" ]; then
    if [ "$DOWNLOAD_QT" = "APT" ]; then
        export QT_ROOT=/usr/lib/`uname -m`-linux-gnu/qt5
        export QT_VERSION=`${QT_ROOT}/bin/qmake -query QT_VERSION`
    elif [ "$DOWNLOAD_QT" = "TRUE" ]; then
        QT_DIR=${TOOLS_DIR}/Qt/${QT_VERSION}
        export QT_ROOT=${QT_DIR}/${QT_VERSION}/gcc_64
    else
        #source /opt/qt${QT_VERSION_DIR}/bin/qt${QT_VERSION_DIR}-env.sh
        export QT_ROOT=/opt/qt${QT_VERSION_DIR}
    fi
    export PATH=$QT_ROOT/bin:$PATH
    export LD_LIBRARY_PATH=$QT_ROOT/lib/i386-linux-gnu:$QT_ROOT/lib:$LD_LIBRARY_PATH
    export PKG_CONFIG_PATH=$QT_ROOT/lib/pkgconfig:$PKG_CONFIG_PATH
fi

if [ "$BUILD_TARGERT" != "windows_msvc" ]; then
    RABBIT_MAKE_JOB_PARA="-j`cat /proc/cpuinfo |grep 'cpu cores' |wc -l`"  #make 同时工作进程参数
    if [ "$RABBIT_MAKE_JOB_PARA" = "-j1" ];then
        RABBIT_MAKE_JOB_PARA=""
    fi
fi
# msys2 中的 perl 不能识别包含 “\” 的路径
if [ "$BUILD_TARGERT" = "windows_msvc" ]; then
    export PATH=/C/Perl/bin:$PATH
fi

if [ "$BUILD_TARGERT" = "windows_mingw" \
    -a -n "$APPVEYOR" ]; then
    export PATH=/C/Qt/Tools/mingw${TOOLCHAIN_VERSION}/bin:$PATH
fi

if [ -n "${QT_ROOT}" ]; then
    export PATH=${QT_ROOT}/bin:$PATH
    if [ -z "$QT_VERSION" ]; then
        export QT_VERSION=`${QT_ROOT}/bin/qmake -query QT_VERSION`
    fi
fi
echo "=== PATH:$PATH"
echo "=== PKG_CONFIG:$PKG_CONFIG"
cd ${SOURCE_DIR}/build_script

for b in ${RABBIT_LIBRARYS_before[$RABBIT_NUMBER]}
do
    bash ./build_$b.sh ${BUILD_TARGERT}
done

for b in ${RABBIT_LIBRARYS_backgroud[$RABBIT_NUMBER]}
do
    bash ./build_$b.sh ${BUILD_TARGERT} &
done

for v in ${RABBIT_LIBRARYS[$RABBIT_NUMBER]}
do
    bash ./build_$v.sh ${BUILD_TARGERT}
done

# 最后一个时，改变其目录名字
echo "RABBIT_LIBRARYS size:${#RABBIT_LIBRARYS[@]}"
if [ ${#RABBIT_LIBRARYS[@]} -eq `expr $RABBIT_NUMBER + 1` ]; then
    PACKAGE_NAME=${SOURCE_DIR}/${BUILD_TARGERT}${TOOLCHAIN_VERSION}_${BUILD_ARCH}_${RABBIT_CONFIG}
    if [ -n "${QT_VERSION}" ]; then
        PACKAGE_NAME=${PACKAGE_NAME}_qt${QT_VERSION}
    fi
    PACKAGE_NAME=${PACKAGE_NAME}_${BUILD_VERSION}
    if [ "$BUILD_TARGERT" = "android" ]; then
        PACKAGE_NAME=${PACKAGE_NAME}_in_windows
    fi
    echo "mv ${RABBIT_BUILD_PREFIX} ${PACKAGE_NAME}"
    mv ${RABBIT_BUILD_PREFIX} ${PACKAGE_NAME}
fi
