#!/bin/bash

set -e -x

sudo apt-get update -qq

mysql -e "CREATE DATABASE npgqct;" -uroot
