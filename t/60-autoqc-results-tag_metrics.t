#########
# Author:        mg8
# Maintainer:    $Author$
# Created:       26 October 2011
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 19;
use Test::Exception;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mx; $r; };

use_ok ('npg_qc::autoqc::results::tag_metrics');

{
  my $r = npg_qc::autoqc::results::tag_metrics->new(id_run => 2, path => 'mypath', position => 1);
  isa_ok ($r, 'npg_qc::autoqc::results::tag_metrics');
}

{
  my $r = npg_qc::autoqc::results::tag_metrics->new(id_run => 2549, position => 1, path => 't');
  is($r->check_name(), 'tag metrics', 'check name is tag metrics');
  is($r->class_name(), 'tag_metrics', 'class name is tag_metrics');
}

{
  my $r;
  lives_ok{
   $r = npg_qc::autoqc::results::tag_metrics->load('t/data/autoqc/tag_metrics/6551_1.tag_metrics.json');
  } 'deserializing from a json file leaves';
  isa_ok ($r, 'npg_qc::autoqc::results::tag_metrics');
  is(join(q[ ], sort {$a <=> $b}  keys %{$r->tags}), '0 1 2 3 4 5 6 7 8 9 10 11 12 168', '14 barcodes are present');
  is(join(q[ ], $r->sorted_tag_indices), '1 2 3 4 5 6 7 8 9 10 11 12 168 0', '14 sorted barcodes are present');
  is($r->tags->{10}, 'TAGCTTGT', 'tag 10 sequence is correct');
  is($r->tags->{0}, 'NNNNNNNN', 'tag zero sequence is correct');
  is($r->matches_percent->{0}, 0.023683, 'matches percent  is correct');
  is($r->spiked_control_index, 168, 'spiked control index is 168');
  is($r->all_reads, 118207260, 'all reads count');
  is($r->errors, 2799524, 'errors reads count');
  is(sprintf("%.2f", $r->variance_coeff), '75.61', 'coeff of variance for perfect matches');
  my $all = 0;
  is(sprintf("%.2f", $r->variance_coeff($all)), '75.61', 'coeff of variance for perfect matches');
  $all = 1;
  is(sprintf("%.2f", $r->variance_coeff($all)), '74.46', 'coeff of variance for all matches');
}

{
  my $r = npg_qc::autoqc::results::tag_metrics->load('t/data/autoqc/tag_metrics/6954_1.tag_metrics.json');
  is($r->spiked_control_index, undef, 'spiked control index is undefined');
  my @expected = (49 .. 96, 168, 0);
  is(join(q[ ], $r->sorted_tag_indices), join(q[ ], @expected), 'tag indices sorted correctly');
}

1;