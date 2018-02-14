#!/bin/bash

# This script was adapted from work by Keith James (keithj). The original source
# can be found as part of the wtsi-npg/data_handling project here:
#
#   https://github.com/wtsi-npg/data_handling
#
# iRODS setup added by Iain Bancarz (ib5), adapted from baton:
#   https://github.com/wtsi-npg/baton

set -e -u -x

# The default build branch for all repositories. This defaults to
# TRAVIS_BRANCH unless set in the Travis build environment.
WTSI_NPG_BUILD_BRANCH=${WTSI_NPG_BUILD_BRANCH:=$TRAVIS_BRANCH}
IRODS_RIP_DIR=${IRODS_RIP_DIR:+$IRODS_RIP_DIR}

sudo apt-get install libgd2-xpm-dev # For npg_tracking
sudo apt-get install liblzma-dev # For npg_qc

# CPAN as in npg_npg_deploy
cpanm --notest --reinstall App::cpanminus
cpanm --quiet --notest --reinstall ExtUtils::ParseXS
cpanm --quiet --notest --reinstall MooseX::Role::Parameterized
cpanm --quiet --notest Alien::Tidyp

# iRODS
wget -q https://github.com/wtsi-npg/disposable-irods/releases/download/${DISPOSABLE_IRODS_VERSION}/disposable-irods-${DISPOSABLE_IRODS_VERSION}.tar.gz -O /tmp/disposable-irods-${DISPOSABLE_IRODS_VERSION}.tar.gz
tar xfz /tmp/disposable-irods-${DISPOSABLE_IRODS_VERSION}.tar.gz -C /tmp
cd /tmp/disposable-irods-${DISPOSABLE_IRODS_VERSION}
./scripts/download_and_verify_irods.sh
./scripts/install_irods.sh
./scripts/configure_irods.sh

# Jansson
wget -q https://github.com/akheron/jansson/archive/v${JANSSON_VERSION}.tar.gz -O /tmp/jansson-${JANSSON_VERSION}.tar.gz
tar xfz /tmp/jansson-${JANSSON_VERSION}.tar.gz -C /tmp
cd /tmp/jansson-${JANSSON_VERSION}
autoreconf -fi
./configure ; make ; sudo make install
sudo ldconfig

# baton
wget -q https://github.com/wtsi-npg/baton/releases/download/${BATON_VERSION}/baton-${BATON_VERSION}.tar.gz -O /tmp/baton-${BATON_VERSION}.tar.gz
tar xfz /tmp/baton-${BATON_VERSION}.tar.gz -C /tmp
cd /tmp/baton-${BATON_VERSION}

IRODS_HOME=
baton_irods_conf="--with-irods"

if [ -n "$IRODS_RIP_DIR" ]
then
    export IRODS_HOME="$IRODS_RIP_DIR/iRODS"
    baton_irods_conf="--with-irods=$IRODS_HOME"
fi

./configure ${baton_irods_conf} ; make ; sudo make install
sudo ldconfig

# WTSI NPG Perl repo dependencies
repos=""
for repo in perl-dnap-utilities ml_warehouse npg_tracking npg_seq_common perl-irods-wrap; do
    cd /tmp
    # Always clone master when using depth 1 to get current tag
    git clone --branch master --depth 1 ${WTSI_NPG_GITHUB_URL}/${repo}.git ${repo}.git
    cd /tmp/${repo}.git
    # Shift off master to appropriate branch (if possible)
    git ls-remote --heads --exit-code origin ${WTSI_NPG_BUILD_BRANCH} && git pull origin ${WTSI_NPG_BUILD_BRANCH} && echo "Switched to branch ${WTSI_NPG_BUILD_BRANCH}"
    repos=$repos" /tmp/${repo}.git"
done

# Finally, bring any common dependencies up to the latest version and
# install
for repo in $repos
do
    cd $repo
    cpanm --quiet --notest --installdeps . || find /home/travis/.cpanm/work -cmin -1 -name '*.log' -exec tail -n20  {} \;		
    perl Build.PL
    ./Build		
    ./Build install
done

cd $TRAVIS_BUILD_DIR
