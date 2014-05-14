#########
# Author:        ajb
# Maintainer:    $Author$
# Created:       2008-07-21
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 18;
use English qw(-no_match_vars);
use IO::Scalar;
use t::util;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/msx; $r; };

use_ok('npg_qc::model::summary');
my $util = t::util->new({fixtures =>1});
{
  my $model = npg_qc::model::summary->new({util => $util});
  isa_ok($model, 'npg_qc::model::summary', 'check model');

  my $complete_runs = $model->complete_runs();
  isa_ok($complete_runs, 'ARRAY', 'complete_runs');
  isa_ok($complete_runs->[0], 'HASH', 'complete_runs->[0]');
  is(scalar@{$complete_runs}, 1, '1 complete run end');
  is($complete_runs->[0]->{id_run}, 10, 'id_run is correct');
  is($complete_runs->[0]->{end}, 1, 'end is correct');
  is($complete_runs->[0]->{paired}, 1, 'paired is correct');
  is($model->complete_runs(), $complete_runs, 'cached within object ok');
}


###
{
  my $model = npg_qc::model::summary->new({util => $util});
  eval{
    my $complete_runs = $model->get_runs_complete_data();
    1;
  };
  is($EVAL_ERROR, q{}, 'no croak for get_runs_complete_data');
  
  eval{
    my $complete_runs = $model->get_paired_runs_complete_data();
    1;
  };
  is($EVAL_ERROR, q{}, 'no croak for get_paired_runs_complete_data');

}


###
{
  my $model = npg_qc::model::summary->new({util => $util});
  my $phasing_info;
  eval{
    $phasing_info = $model->phasing_info(95);
    1;
  };
  is($EVAL_ERROR, q{}, 'no croak for phasing_info');
  is($phasing_info->[0]->[2], 0.73, 'correct phasing for run 95');
  is($phasing_info->[0]->[3], 0.25, 'correct prephasing for run 95');

}

###
{
  my $model = npg_qc::model::summary->new({util => $util});
  $model->id_run(95);
  my $pair_phasing_info;
  eval{
    $pair_phasing_info = $model->pair_phasing_info();
    1;
  };
  is($EVAL_ERROR, q{}, 'no croak for phasing_info');
  is( scalar @{$pair_phasing_info}, 2, 'correct number of paired runs');
  is($pair_phasing_info->[0]->[2], 0.73, 'correct phasing for first run 95');
  is($pair_phasing_info->[0]->[3], 0.25, 'correct phasing for first run 95 paired run');
}

1;
