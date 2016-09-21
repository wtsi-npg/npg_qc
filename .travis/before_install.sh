#!/bin/bash

set -e -x

IRODS_VERSION=${IRODS_VERSION:=4.1.9}

before_install_common() {

    sudo apt-get update -qq

    mysql -e "CREATE DATABASE npgqct;" -uroot

    # shellcheck source=/dev/null
    rm -rf ~/.nvm && git clone https://github.com/creationix/nvm.git ~/.nvm && (pushd ~/.nvm && git checkout v0.31.0 && popd) && source ~/.nvm/nvm.sh && nvm install "${TRAVIS_NODE_VERSION}"

    npm install -g bower@1.7.9
    npm install -g node-qunit-phantomjs

    # Dummy executable files generated for tests use #!/usr/local/bin/bash
    sudo mkdir -p /usr/local/bin
    sudo ln -s /bin/bash /usr/local/bin/bash
    /usr/local/bin/bash --version
}

before_install_4_1_x() {
    wget ${RENCI_URL}/pub/irods/releases/${IRODS_VERSION}/${PLATFORM}/irods-icat-${IRODS_VERSION}-${PLATFORM}-${ARCH}.deb
    wget ${RENCI_URL}/pub/irods/releases/${IRODS_VERSION}/${PLATFORM}/irods-database-plugin-postgres-${PG_PLUGIN_VERSION}-${PLATFORM}-${ARCH}.deb
    wget ${RENCI_URL}/pub/irods/releases/${IRODS_VERSION}/${PLATFORM}/irods-runtime-${IRODS_VERSION}-${PLATFORM}-${ARCH}.deb
    wget ${RENCI_URL}/pub/irods/releases/${IRODS_VERSION}/${PLATFORM}/irods-dev-${IRODS_VERSION}-${PLATFORM}-${ARCH}.deb
}

case $IRODS_VERSION in

    4.1.9)
        before_install_common
        before_install_4_1_x
        ;;

    *)
        echo Unknown iRODS version $IRODS_VERSION
        exit 1
esac