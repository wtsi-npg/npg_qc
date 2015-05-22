#!/software/bin/perl

use strict;
use Getopt::Std;
use Carp;
use JSON;

my %opts;
getopts('qshn:', \%opts);

my $qc22_only = $opts{q};
my $qc26_only = $opts{s};
my $hdr_print = $opts{h};

my %calls = (
  rs1030687 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1032807 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1074042 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1074553 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1079820 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1105176 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs11096957 => {strand => '-', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs1131498 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[Y], },
  rs12828016 => {strand => '+', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs1293153 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1327118 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1363333 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1368136 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1392265 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1395936 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1402695 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1414904 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1426003 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1515002 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1541290 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1541836 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs156318 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs156697 => {strand => '-', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs1585676 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs171953 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1801262 => {strand => '-', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs1805034 => {strand => '+', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs1805087 => {strand => '+', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs1812642 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1843026 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1862456 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1928045 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1952161 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs1961416 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs2016588 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs2077743 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs2077774 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs210310 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs2207782 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs2216629 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs2241714 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[Y], },
  rs2247870 => {strand => '-', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs2286963 => {strand => '+', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs2361128 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs2369898 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs2374061 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs2887851 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs310929 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs349235 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs3742207 => {strand => '-', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs3795677 => {strand => '+', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs3904872 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs4075254 => {strand => '-', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs4619 => {strand => '+', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs4843075 => {strand => '+', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs4925 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[Y], },
  rs502843 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs5215 => {strand => '+', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs522073 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs532841 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[Y], },
  rs6166 => {strand => '-', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs621277 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs649058 => {strand => '+', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs6557634 => {strand => '+', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs6759892 => {strand => '+', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs718757 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs719601 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs722952 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs725029 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs726957 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs727081 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs727336 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs728189 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs7298565 => {strand => '+', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs753381 => {strand => '-', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs754257 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs756497 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs7627615 => {strand => '+', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs763553 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs803172 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs8065080 => {strand => '+', call => q[NN], qc22 => q[Y], qc26 => q[Y], },
  rs890910 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs894240 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs951629 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs952503 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs952768 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs958388 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs965323 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs967344 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs978422 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs995553 => {strand => '-', call => q[NN], qc22 => q[N], qc26 => q[N], },
  rs999072 => {strand => '+', call => q[NN], qc22 => q[N], qc26 => q[N], },
);

my $sample_name = q[];

while(<>) {
  chomp;

  my $h = from_json($_);
  my $do_name = sprintf "%s/%s", (defined $h->{collection}? $h->{collection}: q[COLL_UNSPECIFIED]), (defined $h->{data_object}? $h->{data_object}: q[DATAOBJ_UNSPECIFIED]);

  my @avu_sn = (grep { $_->{attribute} eq q[sample]; } @{$h->{avus}});
  if(@avu_sn == 1) {
    $sample_name = $avu_sn[0]->{value};
  }
  else {
    carp qq[No sample name found for $do_name];
    next;
  }

  my $data = $h->{data};
  for my $row (split q/\n/, $data) {
    my ($rsname, $sn, $call) = (split q/\t/, $row)[1,4,9]; # magic numbers?

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
        $call = join "", sort { $b cmp $a; } (split //, $call);
      }
      else {
        $call = join "", sort (split //, $call);
      }
      $calls{$rsname}->{call} = $call;
    }
  }

  dump_results(\%calls, $sample_name);
  init_calls(\%calls);
}

# flush out calls for last sample
dump_results(\%calls, $sample_name);

sub dump_results {
  my ($calls, $sample_name) = @_;
  # Header line
  if($hdr_print) {
    print join("\t", (q[SampleName], sort keys %calls)), "\n";
  }

  print $sample_name;

  for my $rsname (sort keys %calls) {
    if($qc26_only and ($calls{$rsname}->{qc26} ne q[Y])) {
      next;
    }
    elsif($qc22_only and ($calls{$rsname}->{qc22} ne q[Y])) {
      next;
    }

    print "\t$calls{$rsname}->{call}";
  }
  print "\n";

}

sub init_calls {
  my ($calls) = @_;

  for my $rsname (keys %$calls) {
    $calls->{$rsname}->{call} = q[NN];
  }

  return $calls;
}

