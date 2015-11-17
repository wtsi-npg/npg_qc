#!/bin/bash

set -e -x

cpanm --quiet --notest --installdeps .
perl Build.PL
./Build
export PERL5LIB=$PERL5LIB:$TRAVIS_BUILD_DIR/blib/lib:$TRAVIS_BUILD_DIR/lib

pushd npg_qc_viewer
cpanm --quiet --notest --installdeps .
perl Build.PL --installjsdeps
./Build
popd

./Build test #--verbose
pushd npg_qc_viewer
./Build test #--verbose
popd

pushd npg_qc_viewer/root/static
node-qunit-phantomjs test/test.html --verbose
node-qunit-phantomjs test/test_format_for_csv.html --verbose
popd
