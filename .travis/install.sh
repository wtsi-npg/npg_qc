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

    # Git branch to merge to or custom branch
    WTSI_NPG_BUILD_BRANCH=${WTSI_NPG_BUILD_BRANCH:=$TRAVIS_BRANCH}
    # WTSI NPG Perl repo dependencies
    repos="perl-dnap-utilities ml_warehouse npg_tracking npg_seq_common perl-irods-wrap"
    for repo in $repos
    do
        # Logic of keeping branch consistent was taken from @dkj
        # contribution to https://github.com/wtsi-npg/npg_irods
        cd /tmp
        # Always clone master when using depth 1 to get current tag
        git clone --branch master --depth 1 ${WTSI_NPG_GITHUB_URL}/${repo}.git ${repo}.git
        cd /tmp/${repo}.git
        # Shift off master to appropriate branch (if possible)
        git ls-remote --heads --exit-code origin ${WTSI_NPG_BUILD_BRANCH} && git pull origin ${WTSI_NPG_BUILD_BRANCH} && echo "Switched to branch ${WTSI_NPG_BUILD_BRANCH}"
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

    # Jansson
    wget -q https://github.com/akheron/jansson/archive/v${JANSSON_VERSION}.tar.gz -O /tmp/jansson-${JANSSON_VERSION}.tar.gz
    tar xfz /tmp/jansson-${JANSSON_VERSION}.tar.gz -C /tmp
    cd /tmp/jansson-${JANSSON_VERSION}
    autoreconf -fi
    ./configure ; make ; sudo make install
    sudo ldconfig

    cd $TRAVIS_BUILD_DIR
    sudo ldconfig

    # introduced for irods 4.1.x
    sudo apt-get install -qq python-psutil python-requests
    sudo apt-get install -qq python-sphinx
    sudo apt-get install super libjson-perl jq
    sudo -H pip install jsonschema

    sudo dpkg --contents irods-icat-${IRODS_VERSION}-${PLATFORM}-${ARCH}.deb
    sudo dpkg -i irods-icat-${IRODS_VERSION}-${PLATFORM}-${ARCH}.deb irods-database-plugin-postgres-${PG_PLUGIN_VERSION}-${PLATFORM}-${ARCH}.deb
    sudo dpkg --contents irods-runtime-${IRODS_VERSION}-${PLATFORM}-${ARCH}.deb
    sudo dpkg -i irods-runtime-${IRODS_VERSION}-${PLATFORM}-${ARCH}.deb irods-dev-${IRODS_VERSION}-${PLATFORM}-${ARCH}.deb
}

install_baton() {

    wget -q https://github.com/wtsi-npg/baton/releases/download/${BATON_VERSION}/baton-${BATON_VERSION}.tar.gz -O /tmp/baton-${BATON_VERSION}.tar.gz
    tar xfz /tmp/baton-${BATON_VERSION}.tar.gz -C /tmp
    cd /tmp/baton-${BATON_VERSION}
    ./configure --with-irods
    make
    sudo make install
    cd $TRAVIS_BUILD_DIR
    sudo ldconfig

}

case $IRODS_VERSION in

    4.1.9)
        install_common
        install_4_1_x
        install_baton
        ;;

    *)
        echo Unknown iRODS version $IRODS_VERSION
        exit 1
esac

