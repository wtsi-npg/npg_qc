#!/bin/bash

set -e -x

unset PERL5LIB

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
popd

pushd npg_qc_viewer/root/static
node-qunit-phantomjs test/test.html --verbose
node-qunit-phantomjs test/test_format_for_csv.html --verbose
node-qunit-phantomjs test/test_modify_on_view.html --verbose
popd
