#!/bin/bash

set -e -x

unset PERL5LIB

export PATH=/home/travis/.nvm/versions/node/v${TRAVIS_NODE_VERSION}/bin:$PATH

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
