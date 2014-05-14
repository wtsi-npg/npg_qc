#########
# Author:        gq1
# Maintainer:    $Author$
# Created:       2008-11-24
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 7;
use English qw(-no_match_vars);
use IO::Scalar;
use t::util;
use npg_qc::model::tile_score;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mx; $r; };

use_ok('npg_qc::model::tile_score');

my $util = t::util->new({fixtures =>1});
{
  my $model = npg_qc::model::tile_score->new({util => $util});
  isa_ok($model, 'npg_qc::model::tile_score', '$model');
}

{
  my $model = npg_qc::model::tile_score->new({
    util => $util,
    id_run_tile => 20,
  });
  eval { $model->save() };
  like($EVAL_ERROR, qr{Column\ \'base_count\'\ cannot\ be\ null}, 'field base_count in table tile_score cannot be null');  
}

{
  my $model = npg_qc::model::tile_score->new({
    util => $util,
    id_run_tile       => 20,
    base_count        => 25000, 
    error_count       =>  200,
    blank_count       =>  21,
    unique_alignments       =>  10,
    ua_total_score       => 10 ,
    cycles       =>  35,
    rescore       =>  1,
    score_version       => 1.00 ,
    score_date_run       => '0000-00-00 00:00:00',
    phagealign_version       =>1.0  ,
    phagealign_date_run       => '0000-00-00 00:00:00' ,
    max_blanks       =>  35,
    seq_length       =>  35,
    bases_used       => 'Y' ,

  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'saving data rescore 1'); 
}

{
  my $model = npg_qc::model::tile_score->new({
    util => $util,
    id_run_tile       => 20,
    base_count        => 25000, 
    error_count       =>  200,
    blank_count       =>  21,
    unique_alignments       =>  10,
    ua_total_score       => 10 ,
    cycles       =>  35,
    rescore       =>  1,
    score_version       => 1.00 ,
    score_date_run       => '0000-00-00 00:00:00',
    phagealign_version       =>1.0  ,
    phagealign_date_run       => '0000-00-00 00:00:00' ,
    max_blanks       =>  35,
    seq_length       =>  35,
    bases_used       => 'Y' ,

  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 're-saving data rescore 1'); 
}

{
  my $model = npg_qc::model::tile_score->new({
    util => $util,
    id_run_tile       => 20,
    base_count        => 25000, 
    error_count       =>  200,
    blank_count       =>  21,
    unique_alignments       =>  10,
    ua_total_score       => 10 ,
    cycles       =>  35,
    rescore       =>  0,
    score_version       => 1.00 ,
    score_date_run       => '0000-00-00 00:00:00',
    phagealign_version       =>1.0  ,
    phagealign_date_run       => '0000-00-00 00:00:00' ,
    max_blanks       =>  35,
    seq_length       =>  35,
    bases_used       => 'Y' ,

  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'saving data rescore 0'); 
}

{
  my $model = npg_qc::model::tile_score->new({
    util => $util,
    id_run_tile       => 20,
    base_count        => 25000, 
    error_count       =>  200,
    blank_count       =>  21,
    unique_alignments       =>  10,
    ua_total_score       => 10 ,
    cycles       =>  35,
    rescore       =>  0,
    score_version       => 1.00 ,
    score_date_run       => '0000-00-00 00:00:00',
    phagealign_version       =>1.0  ,
    phagealign_date_run       => '0000-00-00 00:00:00' ,
    max_blanks       =>  35,
    seq_length       =>  35,
    bases_used       => 'Y' ,

  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 're-saving data rescore 0'); 
}
