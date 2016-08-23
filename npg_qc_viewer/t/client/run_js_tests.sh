#!/bin/bash

set -e -x

## npm will only test functionality during deployment process. Linting and
## style checking will only be part of development process using grunt
## configuration.
for test_file in ./t/client/test*.html; do
  echo "Testing: $test_file";
  node-qunit-phantomjs "${test_file}" --verbose;
done

