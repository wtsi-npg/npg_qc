#!/bin/bash

set -e -u -x

NODE_VERSION=$1

WTSI_NPG_BUILD_BRANCH=$2

export PATH=$HOME/.nvm/versions/node/v${NODE_VERSION}/bin:$PATH
export TEST_AUTHOR=1
export WTSI_NPG_iRODS_Test_Resource=testResc
export WTSI_NPG_iRODS_Test_IRODS_ENVIRONMENT_FILE=$HOME/.irods/irods_environment.json
eval $(perl -I ~/perl5ext/lib/perl5/ -Mlocal::lib=~/perl5npg)
eval $(perl -I ~/perl5ext/lib/perl5/ -Mlocal::lib=~/perl5ext)

cpanm --notest --installdeps .  || find $HOME/.cpanm/work -cmin -1 -name '*.log' -exec tail -n20  {} \;
perl Build.PL
./Build
./Build test --verbose

eval $(perl -I ~/perl5ext/lib/perl5/ -Mlocal::lib=~/perl5npg)
./Build install

eval $(perl -I ~/perl5ext/lib/perl5/ -Mlocal::lib=~/perl5ext)
pushd npg_qc_viewer
cpanm --notest --installdeps . || find $HOME/.cpanm/work -cmin -1 -name '*.log' -exec tail -n20  {} \;

perl Build.PL --installjsdeps
./Build
./Build test --verbose
$(npm bin)/grunt -v
popd
