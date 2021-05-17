#!/bin/bash

set -e -x
# set -u fails cause npm install to fail

#Passing in npm version
NPM_VERSION=$1

npm install -g "npm@${NPM_VERSION}"

# Dummy executable files generated for tests use #!/usr/local/bin/bash
sudo mkdir -p /usr/local/bin
sudo ln -s /bin/bash /usr/local/bin/bash
/usr/local/bin/bash --version
