#########
# Author:        ajb
# Maintainer:    $Author$
# Created:       2008-07-16
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 43;
use English qw(-no_match_vars);
use IO::Scalar;
use t::util;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mx; $r; };

use_ok('npg_qc::model::run_tile');

my $util = t::util->new({fixtures =>1});
{
  my $model = npg_qc::model::run_tile->new({util => $util});
  isa_ok($model, 'npg_qc::model::run_tile', '$model');
}
{
  my $model = npg_qc::model::run_tile->new({
    util     => $util,
    id_run   => 1,
    position => 1,
    tile     => 1,
    end      => 1,
  });
  eval { $model->save(); };
  is($EVAL_ERROR, q{}, 'saves ok with id_run, position and end');
  $model->row(1);
  $model->col(1);
  eval { $model->save(); };
  is($EVAL_ERROR, q{}, 'updates row and col ok');
  my $other_end = npg_qc::model::run_tile->new({
    util     => $util,
    id_run   => 1,
    position => 1,
    tile     => 1,
    end      => 2,
  });
  eval { $other_end->save(); };
  is($EVAL_ERROR, q{}, '2nd end saves ok with id_run, position and end');
  my $get_second_end = $model->other_end_tile();
  is($get_second_end->id_run_tile(), $other_end->id_run_tile(), 'second end obtained ok');
  my $get_first_end = $other_end->other_end_tile();
  is($get_first_end->id_run_tile(), $model->id_run_tile(), 'first end obtained ok');
}
{
  my $model = npg_qc::model::run_tile->new({
    util     => $util,
    id_run   => 100,
    position => 7,
    tile     => 330,
    end      => 1,
    row      => 110,
    col      => 3,
  });
  eval { $model->save(); };
  is($EVAL_ERROR, q{}, 'saves ok with id_run, position, end, row and col');
  my $other_end = $model->other_end_tile();
  is($other_end, undef, 'no other end found');
}
{
  my $model = npg_qc::model::run_tile->new({
    util     => $util,
    id_run   => 100,
    position => 1,
    end      => 1,
  });
  eval { $model->save(); };
  like($EVAL_ERROR, qr{Column\ 'tile'\ cannot\ be\ null}, 'tile cannot be null');
}
{
  my $model = npg_qc::model::run_tile->new({
    util     => $util,
    tile     => 100,
    position => 1,
    end      => 1,
  });
  eval { $model->save(); };
  like($EVAL_ERROR, qr{Column\ 'id_run'\ cannot\ be\ null}, 'id_run cannot be null');
}
{
  my $model = npg_qc::model::run_tile->new({
    util   => $util,
    id_run => 100,
    tile   => 1,
    end    => 1,
  });
  eval { $model->save(); };
  like($EVAL_ERROR, qr{Column\ 'position'\ cannot\ be\ null}, 'position cannot be null');
}
{
  my $model = npg_qc::model::run_tile->new({
    util     => $util,
    id_run   => 100,
    position => 1,
    tile     => 1,
  });
  eval { $model->save(); };
  like($EVAL_ERROR, qr{Column\ 'end'\ cannot\ be\ null}, 'end cannot be null');
}

{
  my $model = npg_qc::model::run_tile->new({ util => $util });
  my $run_tiles = $model->all_run_tiles();
  is(scalar@{$run_tiles}, 21, 'corect run tiles obtained');
  my $runs = $model->runs();
  is(scalar@{$runs}, 6, 'correct number of runs found');
  is($model->runs(), $runs, '$runs cached ok');
  $model = $run_tiles->[0];
  is(scalar@{$model->run_tiles_per_run()}, 2, 'correct number of run tiles for run 1 found');
  $model = $run_tiles->[2];
  is(scalar@{$model->run_tiles_per_run_lane()}, 1, 'correct number of run_tiles for run 100, position 7 found')
}

{
  ## tests getting child arrays back
  my$model = npg_qc::model::run_tile->new({
    util => $util,
    id_run_tile => 1,
  });
  isa_ok($model->tile_scores(), 'ARRAY', '$model->tile_scores()');
  isa_ok($model->cumulative_errors_by_cycles(), 'ARRAY', '$model->cumulative_errors_by_cycles()');
  isa_ok($model->error_rate_reference_including_blank(), 'ARRAY', '$model->error_rate_reference_including_blank()');
  isa_ok($model->error_rate_reference_no_blank(), 'ARRAY', '$model->error_rate_reference_no_blank()');
  isa_ok($model->error_rate_relative_reference_cycle_nucleotides(), 'ARRAY', '$model->error_rate_relative_reference_cycle_nucleotides()');
  isa_ok($model->error_rate_relative_sequence_bases(), 'ARRAY', '$model->error_rate_relative_sequence_bases()');
  isa_ok($model->errors_by_cycles(), 'ARRAY', '$model->errors_by_cycles()');
  isa_ok($model->errors_by_cycle_and_nucleotides(), 'ARRAY', '$model->()errors_by_cycle_and_nucleotides');
  isa_ok($model->errors_by_nucleotides(), 'ARRAY', '$model->errors_by_nucleotides()');
  isa_ok($model->information_content_by_cycles(), 'ARRAY', '$model->information_content_by_cycles()');
  isa_ok($model->log_likelihoods(), 'ARRAY', '$model->log_likelihoods()');
  isa_ok($model->most_common_blank_patterns(), 'ARRAY', '$model->most_common_blank_patterns()');
  isa_ok($model->most_common_words(), 'ARRAY', '$model->most_common_words()');
  isa_ok($model->lane_qcs(), 'ARRAY', '$model->lane_qcs()');
}
{
  ## tests getting child arrays back with specific rescore queries
  my$model = npg_qc::model::run_tile->new({
    util => $util,
    id_run_tile => 1,
  });
  isa_ok($model->tile_rescore(), 'npg_qc::model::tile_score', '$model->tile_rescore()');
  isa_ok($model->log_likelihood_rescores(), 'ARRAY', '$model->log_likelihood_rescores()');
  isa_ok($model->most_common_word_rescores(), 'ARRAY', '$model->most_common_words()');
  isa_ok($model->most_common_blank_pattern_rescores(), 'ARRAY', '$model->most_common_blank_patterns()');
  isa_ok($model->error_rate_reference_including_blanks(), 'ARRAY', '$model->error_rate_reference_including_blank()');
  isa_ok($model->error_rate_reference_no_blanks(), 'ARRAY', '$model->error_rate_reference_no_blank()');
  isa_ok($model->error_rate_relative_to_sequence_bases(), 'ARRAY', '$model->error_rate_relative_to_sequence_bases()');
  isa_ok($model->errors_by_nucleotide(), 'ARRAY', '$model->errors_by_nucleotide()');
  isa_ok($model->errors_by_cycle_and_nucleotide(), 'ARRAY', '$model->()errors_by_cycle_and_nucleotide');
  isa_ok($model->information_content_by_cycles(), 'ARRAY', '$model->information_content_by_cycles()');
  isa_ok($model->error_rate_relative_reference_cycle_nucleotide(), 'ARRAY', '$model->error_rate_relative_reference_cycle_nucleotide()');
}
