#!/bin/bash

set -e -u -x

# The default build branch for all repositories. This defaults to
# TRAVIS_BRANCH unless set in the Travis build environment.
WTSI_NPG_BUILD_BRANCH=$1

WTSI_NPG_GITHUB_URL=$2

# CPAN as in npg_npg_deploy
eval $(perl -I ~/perl5ext/lib/perl5/ -Mlocal::lib=~/perl5ext)
cpanm --notest --reinstall App::cpanminus
cpanm --quiet --notest Alien::Tidyp
cpanm --quiet --notest LWP::Protocol::https
cpanm --quiet --notest https://github.com/chapmanb/vcftools-cpan/archive/v0.953.tar.gz

# adding in perl5lib location for npg_qc locations
export PERL5LIB=${WTSI_NPG_BUILD_BRANCH}/lib/npg_qc/:$PERL5LIB

# WTSI NPG Perl repo dependencies
repos=""
for repo in perl-dnap-utilities ml_warehouse npg_tracking npg_seq_common perl-irods-wrap; do
    cd /tmp
    # Always clone master when using depth 1 to get current tag
    git clone --branch master --depth 1 ${WTSI_NPG_GITHUB_URL}/${repo}.git ${repo}.git
    cd /tmp/${repo}.git
    # Shift off master to appropriate branch (if possible)
    git ls-remote --heads --exit-code origin ${WTSI_NPG_BUILD_BRANCH} && git pull origin ${WTSI_NPG_BUILD_BRANCH} && echo "Switched to branch ${WTSI_NPG_BUILD_BRANCH}"
    repos=$repos" /tmp/${repo}.git"
done

# Finally, bring any common dependencies up to the latest version and
# install
for repo in $repos
do
    export PERL5LIB=$repo/blib/lib:$PERL5LIB:$repo/lib
done

for repo in $repos
do
    cd $repo
    cpanm --quiet --notest --installdeps .
    perl Build.PL
    ./Build
done

eval $(perl -I ~/perl5ext/lib/perl5/ -Mlocal::lib=~/perl5npg)

for repo in $repos
do
    cd $repo
    cpanm  --quiet --notest --installdeps .
    ./Build install
    perl Build.PL
    ./Build
done
cd
