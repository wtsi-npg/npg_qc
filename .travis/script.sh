#!/bin/bash

set -e -x

unset PERL5LIB

export PATH=/home/travis/.nvm/versions/node/v${TRAVIS_NODE_VERSION}/bin:$PATH
export TEST_AUTHOR=1
export WTSI_NPG_iRODS_Test_irodsEnvFile=$HOME/.irods/.irodsEnv
export WTSI_NPG_iRODS_Test_IRODS_ENVIRONMENT_FILE=$HOME/.irods/irods_environment.json
export WTSI_NPG_iRODS_Test_Resource=testResc

cpanm --notest --installdeps . || find /home/travis/.cpanm/work -cmin -1 -name '*.log' -exec tail -n20  {} \;
perl Build.PL
./Build

pushd npg_qc_viewer
cpanm --notest --installdeps . || find /home/travis/.cpanm/work -cmin -1 -name '*.log' -exec tail -n20  {} \;
perl Build.PL --installjsdeps
./Build
popd

./Build test --verbose
pushd npg_qc_viewer
./Build test --verbose
grunt -v
popd
