#########
# Author:        ajb
# Maintainer:    $Author$
# Created:       2008-07-22
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
use npg_qc::model::run_tile;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mx; $r; };

use_ok('npg_qc::model::most_common_word');
my $util = t::util->new({fixtures =>1});
{
  my $model = npg_qc::model::most_common_word->new({
    util                => $util,
    id_most_common_word => 1,
    id_run_tile         => 1,
  });
  isa_ok($model, 'npg_qc::model::most_common_word', '$model');
  isa_ok($model->run_tile(), 'npg_qc::model::run_tile', '$model->run_tile()');
}

{
  my $model = npg_qc::model::most_common_word->new({
    util                         => $util,
    id_run_tile                  => 1,
    rank                         => 2,
    occurrence                   => 4,
    word                         =>'TCTGTCTTTTCGTATGCAGGGCGTTGAGTTCGATAAT',
    number_of_sequences          => 3,
    rescore                      => 1,
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'saving data - rescore 1'); 
}

{
  my $model = npg_qc::model::most_common_word->new({
    util                         => $util,
    id_run_tile                  => 1,
    rank                         => 2,
    occurrence                   => 4,
    word                         =>'TCTGTCTTTTCGTATGCAGGGCGTTGAGTTCGATAAT',
    number_of_sequences          => 3,
    rescore                      => 1,
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 're-saving data - rescore 1'); 
}
{
  my $model = npg_qc::model::most_common_word->new({
    util                         => $util,
    id_run_tile                  => 1,
    rank                         => 2,
    occurrence                   => 4,
    word                         =>'TCTGTCTTTTCGTATGCAGGGCGTTGAGTTCGATAAT',
    number_of_sequences          => 3,
    rescore                      => 0,
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'saving data - rescore 0'); 
}

{
  my $model = npg_qc::model::most_common_word->new({
    util                         => $util,
    id_run_tile                  => 1,
    rank                         => 2,
    occurrence                   => 4,
    word                         =>'TCTGTCTTTTCGTATGCAGGGCGTTGAGTTCGATAAT',
    number_of_sequences          => 3,
    rescore                      => 0,
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 're-saving data - rescore 0'); 
}
