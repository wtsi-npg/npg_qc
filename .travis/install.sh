#!/bin/bash

# This script was adapted from work by Keith James (keithj). The original source
# can be found as part of the wtsi-npg/data_handling project here:
#
#   https://github.com/wtsi-npg/data_handling

set -e -x

sudo apt-get install libgd2-xpm-dev # For npg_tracking
sudo apt-get install liblzma-dev # For npg_qc
sudo apt-get install --yes nodejs

# CPAN
cpanm --quiet --notest Alien::Tidyp # For npg_tracking
cpanm --quiet --notest Module::Build
cpanm --quiet --notest Config::Auto # For npg_qc
cpanm --quiet --notest Readonly

# WTSI NPG Perl repo dependencies
cd /tmp
git clone https://github.com/wtsi-npg/ml_warehouse.git ml_warehouse.git
git clone https://github.com/wtsi-npg/npg_ml_warehouse.git npg_ml_warehouse.git
git clone https://github.com/wtsi-npg/npg_tracking.git npg_tracking.git
git clone https://github.com/wtsi-npg/npg_seq_common.git npg_seq_common.git

cd /tmp/ml_warehouse.git    ; git checkout "${DNAP_WAREHOUSE_VERSION}"
cd /tmp/npg_ml_warehouse.git; git checkout "${NPG_ML_WAREHOUSE_VERSION}"
cd /tmp/npg_tracking.git    ; git checkout "${NPG_TRACKING_VERSION}"
cd /tmp/npg_seq_common.git  ; git checkout "${NPG_SEQ_COMMON_VERSION}"

# Fix seq_common
rm /tmp/npg_seq_common.git/t/bin/aligners/bwa/bwa-0.5.8c/bwa
cp /tmp/npg_seq_common.git/t/bin/bwa /tmp/npg_seq_common.git/t/bin/aligners/bwa/bwa-0.5.8c/bwa

rm -r /tmp/npg_seq_common.git/t/data/references/Homo_sapiens/default
cp -R /tmp/npg_seq_common.git/t/data/references/Homo_sapiens/NCBI36 /tmp/npg_seq_common.git/t/data/references/Homo_sapiens/default

# These are cruft, apparently
rm -r /tmp/npg_seq_common.git/t/data/sequence/references2

repos="${TRAVIS_BUILD_DIR} ${TRAVIS_BUILD_DIR}/npg_qc_viewer /tmp/ml_warehouse.git /tmp/npg_ml_warehouse.git /tmp/npg_tracking.git /tmp/npg_seq_common.git"

# Install CPAN dependencies. The src libs are on PERL5LIB because of
# circular dependencies. The blibs are on PERL5LIB because the package
# version, which cpanm requires, is inserted at build time. They must
# be before the libs for cpanm to pick them up in preference.

for repo in $repos
do
  export PERL5LIB=$repo/blib/lib:$PERL5LIB:$repo/lib
done

for repo in $repos
do
  cd "$repo"
  cpanm --quiet --notest --installdeps . || find /home/travis/.cpanm/work -name '*.log' -exec tail -n20  {} \;
  perl Build.PL
  ./Build
done

# Finally, bring any common dependencies up to the latest version and
# install
for repo in $repos
do
  cd "$repo"
  cpanm --quiet --notest --installdeps . || find /home/travis/.cpanm/work -name '*.log' -exec tail -n20  {} \;
  ./Build install
done

cd "$TRAVIS_BUILD_DIR"

npm install -g bower
npm install -g node-qunit-phantomjs

pushd npg_qc_viewer/root/static
bower install
popd
