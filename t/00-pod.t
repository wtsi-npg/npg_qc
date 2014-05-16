#########
# Author:        rmp
# Maintainer:    $Author$
# Created:       2007-10
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#
use strict;
use warnings;
use Test::More;

eval "use Test::Pod 1.00"; ## no critic
plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;
all_pod_files_ok();
