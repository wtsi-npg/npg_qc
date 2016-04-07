#!/bin/bash

set -e -x

sudo apt-get update -qq
mysql -e "CREATE DATABASE npgqct;" -uroot 

rm -rf ~/.nvm && git clone https://github.com/creationix/nvm.git ~/.nvm && (pushd ~/.nvm && git checkout v0.31.0 && popd) && source ~/.nvm/nvm.sh && nvm install $TRAVIS_NODE_VERSION

npm install -g bower@1.7.9
npm install -g node-qunit-phantomjs

# Dummy executable files generated for tests use #!/usr/local/bin/bash
sudo mkdir -p /usr/local/bin
sudo ln -s /bin/bash /usr/local/bin/bash
/usr/local/bin/bash --version
