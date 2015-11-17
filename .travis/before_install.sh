#!/bin/bash

set -e -x

sudo apt-get update -qq
mysql -e "CREATE DATABASE npgqct;" -uroot 

npm install -g bower
npm install -g node-qunit-phantomjs

# Dummy executable files generated for tests use #!/usr/local/bin/bash
sudo mkdir -p /usr/local/bin
sudo ln -s /bin/bash /usr/local/bin/bash
/usr/local/bin/bash --version
