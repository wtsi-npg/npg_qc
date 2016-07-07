#!/bin/bash

set -e -x

sudo apt-key adv --keyserver pgp.mit.edu --recv-keys 5072E1F5 # Import public key for MySQL
sudo apt-get remove --purge "^mysql.*"
sudo apt-get autoremove
sudo apt-get autoclean

# If not deleted and corrupted/not compatible may not let the server start
sudo rm -rf /var/lib/mysql
sudo rm -rf /var/log/mysql

# Specify which version we want
echo "deb http://repo.mysql.com/apt/ubuntu/ precise mysql-5.7" | sudo tee /etc/apt/sources.list.d/mysql.list
sudo -E apt-get update -q
sudo -E apt-get -q -y install mysql-server libmysqlclient-dev libdbd-mysql-perl

sudo /etc/init.d/mysql stop
sleep 5
# Start the server without password
sudo mysqld --skip-grant-tables --explicit_defaults_for_timestamp=false --sql-mode="STRICT_TRANS_TABLES" &

#Give some time for server to start
sleep 10

# print versions
mysql --version
mysql -e "SELECT @@GLOBAL.sql_mode; SELECT @@SESSION.sql_mode; SHOW GLOBAL VARIABLES LIKE '%version%'; show variables like '%time%';" -uroot

