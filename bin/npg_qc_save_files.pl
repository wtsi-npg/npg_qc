#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ( -d "$Bin/../lib/perl5" ? "$Bin/../lib/perl5" : "$Bin/../lib" );

use npg_qc::file_store;

our $VERSION = '0';

my $num_files = npg_qc::file_store->new_with_options()->save_files;
warn qq[$num_files fastqcheck files saved\n];

0;
