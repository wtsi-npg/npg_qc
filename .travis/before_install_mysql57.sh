#!/bin/bash

set -e -x

sudo apt-key adv --keyserver pgp.mit.edu --recv-keys 5072E1F5 # Import public key for MySQL
sudo apt-get remove --purge "^mysql*."
sudo apt-get autoremove
sudo apt-get autoclean

# If not deleted and corrupted/not compatible may not let the server start
sudo rm -rf /var/lib/mysql
sudo rm -rf /var/log/mysql

# Specify which version we want
echo "deb http://repo.mysql.com/apt/ubuntu/ precise mysql-5.7" | sudo tee --append /etc/apt/sources.list.d/mysql.list
sudo apt-get install -q -y mysql-server libmysqlclient-dev libdbd-mysql-perl
sudo apt-get update -qq

sudo /etc/init.d/mysql stop
sleep 5
# Start the server without password
sudo mysqld --skip-grant-tables --sql-mode="STRICT_TRANS_TABLES" &

#Give some time for server to start
sleep 10
