#!/bin/bash

set -e -x
# set -u fails cause npm install to fail

# shellcheck source=/dev/null
rm -rf ~/.nvm && git clone https://github.com/creationix/nvm.git ~/.nvm && (pushd ~/.nvm && git checkout v0.31.0 && popd) && source ~/.nvm/nvm.sh && nvm install "${TRAVIS_NODE_VERSION}"

npm install -g "npm@${TRAVIS_NPM_VERSION}"

# Dummy executable files generated for tests use #!/usr/local/bin/bash
sudo mkdir -p /usr/local/bin
sudo ln -s /bin/bash /usr/local/bin/bash
/usr/local/bin/bash --version
