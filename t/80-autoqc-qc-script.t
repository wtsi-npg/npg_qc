#########
# Author:        mg8
# Maintainer:    $Author$
# Created:       05 August 2009
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$

use strict;
use warnings;
use Test::More tests => 2;
use Cwd;
use File::Spec::Functions qw(catfile);
use File::Temp qw/tempdir/;

$ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/autoqc];

my $path = catfile(cwd, q[t/data/autoqc], q[123456_IL2_2222/Data/Intensities/Bustard-2009-10-01/PB_cal/archive]);
my $odir = tempdir(CLEANUP => 1);

my @args = ("bin/qc", "--position=1", "--check=qX_yield", "--archive_path=$path", "--qc_path=$odir");
is (system(@args), 0, 'script exited normally');

@args = ("bin/qc", "--id_run=2222", "--position=1", "--check=qX_yield", "--tag_index=1", "--qc_in=$path", "--qc_out=$odir");
is (system(@args), 0, 'script exited normally');

1;
