#!/bin/bash

set -e -x

perl Build.PL
./Build clean
./Build
./Build test --test-files '*.t'

pushd npg_qc_viewer
perl Build.PL
./Build clean
./Build
./Build test --test-files 't/*.t'
popd

pushd npg_qc_viewer/root/static
node-qunit-phantomjs test/test.html --verbose
node-qunit-phantomjs test/test_format_for_csv.html --verbose
popd
