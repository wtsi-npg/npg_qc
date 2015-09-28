#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Std;
use Carp;
use Readonly;
use JSON;

our $VERSION = '0';

Readonly::Scalar my $FLUIDIGM_RESULT_RSNAME_COL => 1;
Readonly::Scalar my $FLUIDIGM_RESULT_SAMPLE_NAME_COL => 4;
Readonly::Scalar my $FLUIDIGM_RESULT_CALL_COL => 9;

Readonly::Scalar my $MAX_FATAL_ERRS => 64;

my %opts;
getopts('qshn:', \%opts);

my $qc22_only = $opts{q};
my $qc26_only = $opts{s};
my $hdr_print = $opts{h};

my %calls = (
  rs1030687 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1032807 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1074042 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1074553 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1079820 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1105176 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs11096957 => {strand => q[-], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs1131498 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[Y], },
  rs12828016 => {strand => q[+], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs1293153 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1327118 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1363333 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1368136 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1392265 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1395936 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1402695 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1414904 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1426003 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1515002 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1541290 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1541836 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs156318 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs156697 => {strand => q[-], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs1585676 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs171953 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1801262 => {strand => q[-], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs1805034 => {strand => q[+], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs1805087 => {strand => q[+], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs1812642 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1843026 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1862456 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1928045 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1952161 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1961416 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs2016588 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs2077743 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs2077774 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs210310 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs2207782 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs2216629 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs2241714 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[Y], },
  rs2247870 => {strand => q[-], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs2286963 => {strand => q[+], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs2361128 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs2369898 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs2374061 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs2887851 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs310929 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs349235 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs3742207 => {strand => q[-], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs3795677 => {strand => q[+], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs3904872 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs4075254 => {strand => q[-], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs4619 => {strand => q[+], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs4843075 => {strand => q[+], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs4925 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[Y], },
  rs502843 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs5215 => {strand => q[+], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs522073 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs532841 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[Y], },
  rs6166 => {strand => q[-], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs621277 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs649058 => {strand => q[+], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs6557634 => {strand => q[+], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs6759892 => {strand => q[+], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs718757 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs719601 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs722952 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs725029 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs726957 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs727081 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs727336 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs728189 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs7298565 => {strand => q[+], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs753381 => {strand => q[-], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs754257 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs756497 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs7627615 => {strand => q[+], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs763553 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs803172 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs8065080 => {strand => q[+], call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs890910 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs894240 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs951629 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs952503 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs952768 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs958388 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs965323 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs967344 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs978422 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs995553 => {strand => q[-], call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs999072 => {strand => q[+], call => q[NN], qc22 => q[N], qc26 => q[N], },
);

my $errexit_count = 0;
my $sample_name = q[];

while(<>) {
  chomp;

  my $h = from_json($_);

  if($h->{error} or $errexit_count) {
    # any error reported in the input is fatal, but report the first $MAX_FATAL_ERRS occurrences, then just finish
    #  reading the input (to avoid potential "broken pipe" upset to an iRODS client supplying the input), then croak
    if($h->{error}) {
      if(++$errexit_count < $MAX_FATAL_ERRS) { # fatal, but not right away
        carp q[error in JSON input; code: ], $h->{error}->{code}, q[; message: ], $h->{error}->{message};
      }
    }

    next;
  }

  my $do_name = sprintf q[%s/%s], (defined $h->{collection}? $h->{collection}: q[COLL_UNSPECIFIED]), (defined $h->{data_object}? $h->{data_object}: q[DATAOBJ_UNSPECIFIED]);

  my @avu_sn = (grep { $_->{attribute} eq q[sample]; } @{$h->{avus}});
  if(@avu_sn == 1) {
    $sample_name = $avu_sn[0]->{value};
  }
  else {
    carp qq[No sample name found for $do_name];
    next;
  }

  my $data = $h->{data};
  for my $row (split /\n/smx, $data) {
    my ($rsname, $sn, $call) = (split /\t/smx, $row)[$FLUIDIGM_RESULT_RSNAME_COL,$FLUIDIGM_RESULT_SAMPLE_NAME_COL,$FLUIDIGM_RESULT_CALL_COL];

    ## no critic qw(ControlStructures::ProhibitUnlessBlocks)
    unless($rsname) {
      carp q[No rsname (], $do_name, q[)];
      next;
    }

    $call =~ tr/://d;

    if($call eq q[No Call] or $call eq q[Invalid] or $call eq q[NTC]) { $call = q[NN]; }

    if($calls{$rsname}) { $calls{$rsname}->{call} = $call };
    if($calls{$rsname}) {
      if($calls{$rsname}->{strand} eq q[-]) {
        $call =~ tr/ACGT/TGCA/;
        ## no critic qw(BuiltinFunctions::ProhibitReverseSortBlock)
        $call = join q[], sort { $b cmp $a; } (split //smx, $call);
      }
      else {
        $call = join q[], sort split //smx, $call;
      }
      $calls{$rsname}->{call} = $call;
    }
  }

  dump_results(\%calls, $sample_name);
  init_calls(\%calls);
}

if($errexit_count) {
  croak q[Maximum fatal errors (], $MAX_FATAL_ERRS , q[) detected, exiting];
}

sub dump_results {
  my ($calls, $sn) = @_;
  # Header line
  if($hdr_print) {
    print join("\t", (q[SampleName], sort keys %calls)), "\n" or croak q[print fail];
  }

  print $sn or croak q[print fail];

  for my $rsname (sort keys %calls) {
    if($qc26_only and ($calls{$rsname}->{qc26} ne q[Y])) {
      next;
    }
    elsif($qc22_only and ($calls{$rsname}->{qc22} ne q[Y])) {
      next;
    }

    print "\t$calls{$rsname}->{call}" or croak q[print fail];
  }
  print "\n" or croak q[print fail];

  return;
}

sub init_calls {
  my ($calls) = @_;

  for my $rsname (keys %{$calls}) {
    $calls->{$rsname}->{call} = q[NN];
  }

  return $calls;
}

