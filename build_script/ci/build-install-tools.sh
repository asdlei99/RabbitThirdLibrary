#!/bin/bash 
#下载工具  

set -e

SOURCE_DIR=$(cd `dirname $0`; pwd)/../..
if [ -n "$1" ]; then
    SOURCE_DIR=$1
fi
echo $SOURCE_DIR
TOOLS_DIR=${SOURCE_DIR}/Tools
PACKAGE_DIR=${SOURCE_DIR}/Package
if [ ! -f "${TOOLS_DIR}" ]; then
    mkdir -p ${TOOLS_DIR}
fi
if [ ! -d ${PACKAGE_DIR} ]; then
    mkdir -p ${PACKAGE_DIR}
fi

function function_install_yasm()
{
    #安装 yasm
    mkdir -p ${TOOLS_DIR}/src
    cd ${TOOLS_DIR}/src
    wget -c -nv http://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz 
    tar xzf yasm-1.3.0.tar.gz
    cd yasm-1.3.0/
    ./configure > /dev/null && sudo make install -j2 > /dev/null
    cd ${SOURCE_DIR}
}

function function_common()
{
    cd ${TOOLS_DIR}
    
    # Qt qt安装参见：https://github.com/benlau/qtci  
    if [ "$DOWNLOAD_QT" = "TRUE" ]; then
        QT_DIR=`pwd`/Qt/${QT_VERSION}
        if [ ! -d "${QT_DIR}" ]; then
            if [ "${QT_VERSION}" = "5.6.3" ]; then
                wget -c --no-check-certificate -nv http://download.qt.io/official_releases/qt/${QT_VERSION_DIR}/${QT_VERSION}/qt-opensource-linux-x64-android-${QT_VERSION}.run
                bash ${SOURCE_DIR}/build_script/ci/qt-installer.sh qt-opensource-linux-x64-android-${QT_VERSION}.run ${QT_DIR}
                rm qt-opensource-linux-x64-android-${QT_VERSION}.run
            else
                wget -c --no-check-certificate -nv http://download.qt.io/official_releases/qt/${QT_VERSION_DIR}/${QT_VERSION}/qt-opensource-linux-x64-${QT_VERSION}.run
                bash ${SOURCE_DIR}/build_script/ci/qt-installer.sh qt-opensource-linux-x64-${QT_VERSION}.run ${QT_DIR}
                rm qt-opensource-linux-x64-${QT_VERSION}.run
            fi
        fi
    fi
}

function install_android()
{
    if [ -n "$1" ]; then
        NDK="ndk-bundle"
    fi
    cd ${TOOLS_DIR}
    if [ ! -d "`pwd`/android-sdk" ]; then
        cd ${PACKAGE_DIR}
        ANDROID_STUDIO_VERSION=191.5900203
        ANDROID_STUDIO_PACKAGE=android-studio-ide-${ANDROID_STUDIO_VERSION}-linux.tar.gz
        if [ ! -f ${ANDROID_STUDIO_PACKAGE} ]; then
            wget -c -nv https://dl.google.com/dl/android/studio/ide-zips/3.5.1.0/${ANDROID_STUDIO_PACKAGE}
        fi
        tar xzf android-studio-ide-${ANDROID_STUDIO_VERSION}-linux.tar.gz -C ${TOOLS_DIR}
        cd ${TOOLS_DIR}
        export JAVA_HOME=`pwd`/android-studio/jre
        export PATH=${JAVA_HOME}/bin:$PATH
        cd ${PACKAGE_DIR}
        SDK_PACKAGE=sdk-tools-linux-4333796.zip
        if [ ! -f ${SDK_PACKAGE} ]; then
            wget -c -nv https://dl.google.com/android/repository/${SDK_PACKAGE}
        fi
        cd ${TOOLS_DIR}
        mkdir android-sdk
        cd android-sdk
        unzip -q ${PACKAGE_DIR}/${SDK_PACKAGE} -d `pwd`
        
        echo "Install sdk and ndk ......"
        if [ -n "${ANDROID_API}" ]; then
            PLATFORMS="platforms;${ANDROID_API}"
        else
            PLATFORMS="platforms"
        fi
        if [ -z "${BUILD_TOOS_VERSION}" ]; then
            BUILD_TOOS_VERSION="28.0.3"
        fi
        
        (sleep 5 ; num=0 ; while [ $num -le 5 ] ; do sleep 1 ; num=$(($num+1)) ; printf 'y\r\n' ; done ) \
        | ./tools/bin/sdkmanager "platform-tools" "build-tools;${BUILD_TOOS_VERSION}" "${PLATFORMS}" ${NDK} > /dev/null
        if [ -n "${NDK}" ]; then
            if [ ! -d ${TOOLS_DIR}/android-ndk ]; then
                ln -s ${TOOLS_DIR}/android-sdk/ndk-bundle ${TOOLS_DIR}/android-ndk
            fi
        fi
    fi
}

function install_android_sdk_and_ndk()
{
    install_android
    NDK_PACKAGE=android-ndk-r21-linux-x86_64.zip
    cd ${PACKAGE_DIR}
    if [ ! -f ${NDK_PACKAGE} ]; then
        wget -c -nv https://dl.google.com/android/repository/${NDK_PACKAGE}
    fi
    unzip -q ${NDK_PACKAGE} -d ${TOOLS_DIR}
    cd ${TOOLS_DIR}
    mv android-ndk-r21 android-ndk
}

function function_android()
{
    cd ${TOOLS_DIR}
    
    #sudo apt-get update -y -qq
    sudo apt-get install ant -qq -y

    install_android_sdk_and_ndk
    function_common
    cd ${SOURCE_DIR}
}

function function_unix()
{
    #汇编工具yasm
    #function_install_yasm
    sudo apt-get install -qq -y yasm

    #sudo apt-get update -y -qq
    sudo apt-get install debhelper fakeroot -y -qq
    sudo apt-get install -y -qq libglu1-mesa-dev \
        libxkbcommon-x11-dev \
        libpulse-mainloop-glib0 \
        libgstreamer1.0-dev \
        libgstreamer-plugins-base1.0-dev \
        gstreamer1.0-pulseaudio

    if [ "$DOWNLOAD_QT" = "APT" ]; then
        sudo apt-get install -y -qq qttools5-dev qttools5-dev-tools \
            qtbase5-dev qtbase5-dev-tools \
            qtmultimedia5-dev
        sudo ln -s /usr/lib/`uname -m`-linux-gnu/cmake /usr/lib/`uname -m`-linux-gnu/qt5/cmake
    fi

    function_common

    cd ${SOURCE_DIR}
}

function function_mingw()
{
    #汇编工具yasm
    #function_install_yasm

    if [ "true" == "$RABBIT_BUILD_THIRDLIBRARY" ]; then
        export RABBIT_BUILD_CROSS_HOST=i686-w64-mingw32 #i586-mingw32msvc
    fi

    function_common
    cd ${SOURCE_DIR}
}

case ${BUILD_TARGERT} in
    android)
        function_android
        ;;
    unix)
        function_unix
        ;;
    windows_mingw)
        function_mingw
        ;;
    *)
    echo "There aren't ${BUILD_TARGERT}"
        ;;
esac

cd ${SOURCE_DIR}
