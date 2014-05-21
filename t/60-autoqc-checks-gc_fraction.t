#########
# Author:        mg8
# Maintainer:    $Author$
# Created:       04 January 2010
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 28;
use Test::Deep;
use Test::Exception;
use Cwd;
use File::Spec::Functions qw(catfile);

use npg_qc::autoqc::results::gc_fraction;

local $ENV{'NPG_WEBSERVICE_CACHE_DIR'} = q[t/data/autoqc];
my $repos = cwd . '/t/data/autoqc';

use_ok ('npg_qc::autoqc::checks::gc_fraction');

{
    my $r = npg_qc::autoqc::checks::gc_fraction->new(path => 't/data/autoqc/090721_IL29_2549/data', 
                                                     position =>1,
                                                     id_run => 254,
                                                     repository => $repos, );
    isa_ok ($r, 'npg_qc::autoqc::checks::gc_fraction');
}


{
    my $qc = npg_qc::autoqc::checks::gc_fraction->new(position => 2, path => 'nonexisting', id_run => 2549, repository => $repos, );
    throws_ok {$qc->execute()} qr/directory\ nonexisting\ does\ not\ exist/, 'execute: error on nonexisting path';
}

{
    my $gc = npg_qc::autoqc::checks::gc_fraction->new(position => 2, path => 'nonexisting', id_run => 2549, repository => $repos, );
    my $result = $gc->_gc_percent({A => 10.0, C => 20.0, G => 25.0, T => 30.0,});
    is ($result, ((20.0+25.0)/(10.0+20.0+25.0+30.0))*100, 'gc percent calculation');
}

{
   my $check = npg_qc::autoqc::checks::gc_fraction->new(
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      position  => 1,
                                                      id_run    => 2549,
                                                      ref_base_count_path => q[],
                                                      repository => $repos, 
                                                     );
   $check->execute();
 
   is($check->result->pass, undef, 'pass undefined');
   is($check->result->threshold_difference, 20 , 'threshold difference');
   is($check->result->ref_gc_percent, undef, 'reference gc content undefined');

   my $gc_string = sprintf("%.2f", $check->result->forward_read_gc_percent);
   is($gc_string, '46.39', 'forward read gc percent');

   $gc_string = sprintf("%.2f", $check->result->reverse_read_gc_percent);
   is($gc_string, '46.39', 'reverse read gc percent');

   is($check->result->forward_read_filename, q[2549_1_1.fastqcheck], 'forward read name');
   is($check->result->reverse_read_filename, q[2549_1_2.fastqcheck], 'reverse read name');

   is($check->ref_base_count_path, q[], 'base count path undefined');
}


{
   my $check = npg_qc::autoqc::checks::gc_fraction->new(
                                                         path      => 't/data/autoqc/090721_IL29_2549/data',
                                                         position  => 2,
                                                         id_run => 2549,
                                                         repository => $repos, 
                                                       );
   $check->execute();

   is($check->result->pass(), undef, 'single run pass undefined');
   is($check->result->threshold_difference, 20 , 'threshold difference');
   my $gc_string = sprintf("%.2f", $check->result->forward_read_gc_percent);
   is($gc_string, '44.44', 'forward read gc percent');
   is($check->result->reverse_read_gc_percent, undef, 'forward read gc percent undefined for a single run');
   is($check->result->forward_read_filename, q[2549_2_1.fastqcheck], 'forward read name');
   is($check->result->reverse_read_filename, undef, 'reverse read name undefined for a single run');

   is($check->ref_base_count_path, undef, 'base count path undefined');
}


{
   my $bc_path = catfile(cwd, q[t/data/autoqc/Homo_sapiens.NCBI36.48.dna.all.fa]);
   my $check = npg_qc::autoqc::checks::gc_fraction->new(
                                                         path      => 't/data/autoqc/090721_IL29_2549/data',
                                                         position  => 8,
                                                         id_run    => 2549,
                                                         ref_base_count_path => $bc_path,
                                                         repository => $repos, 
                                                       );
   # lane 8 is human
   $check->execute();
 
   is($check->result->pass, 1, 'pass undefined');
   is($check->result->threshold_difference, 20 , 'threshold difference');

   my $gc_string = sprintf("%.2f", $check->result->ref_gc_percent);
   is($gc_string, '40.89', 'reference gc content undefined');

   $gc_string = sprintf("%.2f", $check->result->forward_read_gc_percent);
   is($gc_string, '44.24', 'forward read gc percent');

   $gc_string = sprintf("%.2f", $check->result->reverse_read_gc_percent);
   is($gc_string, '44.28', 'reverse read gc percent');

   is($check->result->forward_read_filename, q[2549_8_1.fastqcheck], 'forward read name');
   is($check->result->reverse_read_filename, q[2549_8_2.fastqcheck], 'reverse read name');

   is($check->ref_base_count_path, $bc_path, 'base count path');
   is($check->result->comments, undef, 'no comments');
}
