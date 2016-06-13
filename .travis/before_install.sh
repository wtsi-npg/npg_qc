#!/bin/bash

set -e -x

sudo apt-key adv --keyserver pgp.mit.edu --recv-keys 5072E1F5
sudo apt-get remove --purge "^mysql.*"
sudo apt-get autoremove
sudo apt-get autoclean

sudo apt-get update -qq

sudo rm -rf /var/lib/mysql
sudo rm -rf /var/log/mysql

echo "deb http://repo.mysql.com/apt/ubuntu/ precise mysql-5.7" | sudo tee --append /etc/apt/sources.list.d/mysql.list
sudo apt-get update -q
#MYSQL_PASS="777"
#echo mysql-server mysql-server/root_password password "${MYSQL_PASS}" | sudo debconf-set-selections
#echo mysql-server mysql-server/root_password_again password "${MYSQL_PASS}" | sudo debconf-set-selections
sudo -E apt-get install -q -y mysql-server

sudo /etc/init.d/mysql stop
sudo mysqld --skip-grant-tables &

#echo "dbpass=${MYSQL_PASS}" | tee -a  npg_qc/data/npg_qc_web/config.ini

sleep 20 && mysql -e "CREATE DATABASE npgqct;" -uroot

# shellcheck source=/dev/null
rm -rf ~/.nvm && git clone https://github.com/creationix/nvm.git ~/.nvm && (pushd ~/.nvm && git checkout v0.31.0 && popd) && source ~/.nvm/nvm.sh && nvm install "${TRAVIS_NODE_VERSION}"

npm install -g bower@1.7.9
npm install -g node-qunit-phantomjs

# Dummy executable files generated for tests use #!/usr/local/bin/bash
sudo mkdir -p /usr/local/bin
sudo ln -s /bin/bash /usr/local/bin/bash
/usr/local/bin/bash --version
