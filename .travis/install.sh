#!/bin/bash

# This script was adapted from work by Keith James (keithj). The original source
# can be found as part of the wtsi-npg/data_handling project here:
#
#   https://github.com/wtsi-npg/data_handling

set -e -x

sudo apt-get install libgd2-xpm-dev # For npg_tracking
sudo apt-get install liblzma-dev # For npg_qc
sudo apt-get install --yes nodejs

# CPAN as in npg_npg_deploy
cpanm --notest --reinstall App::cpanminus
cpanm --quiet --notest --reinstall ExtUtils::ParseXS
cpanm --quiet --notest --reinstall MooseX::Role::Parameterized
cpanm --quiet --notest Alien::Tidyp

# WTSI NPG Perl repo dependencies
cd /tmp
git clone --branch devel --depth 1 https://github.com/wtsi-npg/ml_warehouse.git ml_warehouse.git
git clone --branch devel --depth 1 https://github.com/wtsi-npg/npg_tracking.git npg_tracking.git
git clone --branch devel --depth 1 https://github.com/wtsi-npg/npg_seq_common.git npg_seq_common.git

# Fix seq_common
rm /tmp/npg_seq_common.git/t/bin/aligners/bwa/bwa-0.5.8c/bwa
cp /tmp/npg_seq_common.git/t/bin/bwa /tmp/npg_seq_common.git/t/bin/aligners/bwa/bwa-0.5.8c/bwa

rm -r /tmp/npg_seq_common.git/t/data/references/Homo_sapiens/default
cp -R /tmp/npg_seq_common.git/t/data/references/Homo_sapiens/NCBI36 /tmp/npg_seq_common.git/t/data/references/Homo_sapiens/default

repos="/tmp/ml_warehouse.git /tmp/npg_tracking.git /tmp/npg_seq_common.git"

# Install CPAN dependencies. The src libs are on PERL5LIB because of
# circular dependencies. The blibs are on PERL5LIB because the package
# version, which cpanm requires, is inserted at build time. They must
# be before the libs for cpanm to pick them up in preference.

for repo in $repos
do
  export PERL5LIB=$repo/blib/lib:$repo/lib:$PERL5LIB
done

for repo in $repos
do
  cd "$repo"
  cpanm --quiet --notest --installdeps . || find /home/travis/.cpanm/work -cmin -1 -name '*.log' -exec tail -n20  {} \;
  perl Build.PL
  ./Build
  ./Build install
done

cd "$TRAVIS_BUILD_DIR"
