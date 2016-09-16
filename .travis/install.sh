#!/bin/bash

# This script was adapted from work by Keith James (keithj). The original source
# can be found as part of the wtsi-npg/data_handling project here:
#
#   https://github.com/wtsi-npg/data_handling
#
# iRODS setup added by Iain Bancarz (ib5), adapted from baton:
#   https://github.com/wtsi-npg/baton

set -e -x

IRODS_VERSION=${IRODS_VERSION:=4.1.9}

install_common() {

    sudo apt-get install libgd2-xpm-dev # For npg_tracking
    sudo apt-get install liblzma-dev # For npg_qc
    sudo apt-get install --yes nodejs

    # CPAN as in npg_npg_deploy
    cpanm --notest --reinstall App::cpanminus
    cpanm --quiet --notest --reinstall ExtUtils::ParseXS
    cpanm --quiet --notest --reinstall MooseX::Role::Parameterized
    cpanm --quiet --notest Alien::Tidyp
    cpanm --no-lwp --notest https://github.com/wtsi-npg/perl-dnap-utilities/releases/download/${DNAP_UTILITIES_VERSION}/WTSI-DNAP-Utilities-${DNAP_UTILITIES_VERSION}.tar.gz

    # WTSI NPG Perl repo dependencies
    cd /tmp
    git clone --branch devel --depth 1 https://github.com/wtsi-npg/ml_warehouse.git ml_warehouse.git
    #git clone --branch devel --depth 1 https://github.com/wtsi-npg/npg_tracking.git npg_tracking.git
    git clone --branch lims4composition --depth 1 https://github.com/mgcam/npg_tracking.git npg_tracking.git
    git clone --branch devel --depth 1 https://github.com/wtsi-npg/npg_seq_common.git npg_seq_common.git
    git clone --branch devel --depth 1 https://github.com/wtsi-npg/perl-irods-wrap.git perl-irods-wrap.git

    repos="/tmp/ml_warehouse.git /tmp/npg_tracking.git /tmp/npg_seq_common.git /tmp/perl-irods-wrap.git"

    for repo in $repos
    do
        cd $repo
        cpanm --quiet --notest --installdeps . || find /home/travis/.cpanm/work -cmin -1 -name '*.log' -exec tail -n20  {} \;
        perl Build.PL
        ./Build
        ./Build install
    done
    
    cd $TRAVIS_BUILD_DIR
    sudo ldconfig
}

install_4_1_x() {
    # common to irods 3.3.1 and 4.1.x
    sudo apt-get install -qq odbc-postgresql unixodbc-dev
    sudo apt-get install -qq python-sphinx
    sudo -H pip install breathe

    wget http://downloads.sourceforge.net/project/check/check/0.9.14/check-0.9.14.tar.gz -O /tmp/check-0.9.14.tar.gz
    tar xfz /tmp/check-0.9.14.tar.gz -C /tmp
    cd /tmp/check-0.9.14
    autoreconf -fi
    ./configure ; make ; sudo make install

    wget https://github.com/akheron/jansson/archive/v2.7.tar.gz -O /tmp/jansson-2.7.tar.gz
    tar xfz /tmp/jansson-2.7.tar.gz -C /tmp
    cd /tmp/jansson-2.7
    autoreconf -fi
    ./configure ; make ; sudo make install

    cd $TRAVIS_BUILD_DIR
    #sudo ldconfig

    # introduced for irods 4.1.x
    sudo apt-get install -qq python-psutil python-requests
    sudo apt-get install -qq python-sphinx
    sudo apt-get install super libjson-perl jq
    sudo -H pip install jsonschema

    pwd
    ls

    sudo dpkg -i irods-icat-${IRODS_VERSION}-${PLATFORM}-${ARCH}.deb irods-database-plugin-postgres-${PG_PLUGIN_VERSION}-${PLATFORM}-${ARCH}.deb
    sudo dpkg -i irods-runtime-${IRODS_VERSION}-${PLATFORM}-${ARCH}.deb irods-dev-${IRODS_VERSION}-${PLATFORM}-${ARCH}.deb
}


case $IRODS_VERSION in

    4.1.9)
        install_common
        install_4_1_x
        ;;

    *)
        echo Unknown iRODS version $IRODS_VERSION
        exit 1
esac
