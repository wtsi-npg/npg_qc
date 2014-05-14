#########
# Author:        mg8
# Maintainer:    $Author$
# Created:       11 May 2012
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 20;
use Test::Exception;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mx; $r; };

use_ok ('npg_qc::autoqc::results::alignment_filter_metrics');

{
  my $r = npg_qc::autoqc::results::alignment_filter_metrics->load('t/data/autoqc/af_metrics/7880_1#0.alignment_filter_metrics.json');
  isa_ok ($r, 'npg_qc::autoqc::results::alignment_filter_metrics');
  is($r->check_name(), 'alignment filter metrics', 'check name');
  is($r->class_name(), 'alignment_filter_metrics', 'class name');
  is(join(q[:], $r->refs), 'Human NCBI37:Plasmodium falciparum 3D7 Oct11', 'list of references');

  my $stats = $r->stats_per_ref;
  is ($stats->{'Human NCBI37'}->{count}, 48666, 'human reads count');
  is ($stats->{'Plasmodium falciparum 3D7 Oct11'}->{count}, 113313, 'plasmodium reads count');
  is ($stats->{'Plasmodium falciparum 3D7 Oct11'}->{count_unmapped}, 76221, 'plasmodium unaligned reads count');

  my $ambiguous_reads = $r->ambiguous_reads;
  is ($ambiguous_reads->{count}, 613, 'number of reads that align to multiple references');

  my $chimeric_reads = $r->chimeric_reads;
  is ($chimeric_reads->{count}, 176, 'number of chimeric reads');

  is ($r->total_reads, 161979, 'total reads number');
}

{
  my $r = npg_qc::autoqc::results::alignment_filter_metrics->load('t/data/autoqc/af_metrics/7908_1#1.alignment_filter_metrics.json');

  is(join(q[:], $r->refs), 'phix-illumina.fa:Unmapped', 'list of references');

  my $stats = $r->stats_per_ref;
  is ($stats->{'phix-illumina.fa'}->{count}, 107, 'mapped phix reads count');
  is ($stats->{'Unmapped'}->{count}, 85180763, 'unmapped reads count');
  ok (!exists $stats->{'Unmapped'}->{count_unmapped}, 'separate unmapped count is not available');
  is ($r->ambiguous_reads->{count}, 0, 'number of reads that align to multiple references');
  is ($r->chimeric_reads->{count}, 0, 'number of chimeric reads');
  is ($r->ambiguous_reads->{percent}, 0, 'percent of reads that align to multiple references');
  is ($r->chimeric_reads->{percent}, 0, 'percent of chimeric reads');
  is ($r->total_reads, 85180870, 'total reads number');
}

1;