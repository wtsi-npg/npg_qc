#!/bin/bash

set -e -x

IRODS_VERSION=${IRODS_VERSION:=4.1.9}

before_script_4_1_x() {
    sudo -E -u postgres createuser -D -R -S irods
    sudo -E -u postgres createdb -O irods ICAT
    sudo -E -u postgres sh -c "echo \"ALTER USER irods WITH PASSWORD 'irods'\" | psql"
    sudo /var/lib/irods/packaging/setup_irods.sh < ./.travis/setup_irods
    sudo jq -f ./.travis/server_config /etc/irods/server_config.json > server_config.tmp
    sudo mv server_config.tmp /etc/irods/server_config.json
    ls -l /etc/irods
    sudo /etc/init.d/irods restart
    sudo -E su irods -c "iadmin mkuser $USER rodsadmin ; iadmin moduser $USER password testuser"
    sudo -E su irods -c "iadmin lu $USER"
    sudo -E su irods -c "mkdir -p /var/lib/irods/iRODS/Test"
    sudo -E su irods -c "iadmin mkresc testResc unixfilesystem `hostname --fqdn`:/var/lib/irods/iRODS/Test"
    mkdir $HOME/.irods
    sed -e "s#__USER__#$USER#" -e "s#__HOME__#$HOME#" < ./.travis/irodsenv.json > $HOME/.irods/irods_environment.json
    cat $HOME/.irods/irods_environment.json
    ls -la $HOME/.irods/
    echo testuser | script -q -c "iinit"
    ls -la $HOME/.irods/
}


case $IRODS_VERSION in

    4.1.9)
        before_script_4_1_x
        ;;

    *)
        echo Unknown iRODS version $IRODS_VERSION
        exit 1
esac