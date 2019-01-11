use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;
use File::Temp qw/tempdir/;

use_ok('npg_qc::autoqc::checks::spatial_filter');

{
  my $check = npg_qc::autoqc::checks::spatial_filter->new(
    position => 2, id_run => 2549, qc_in => ['t']);
  isa_ok ($check, 'npg_qc::autoqc::checks::spatial_filter');
  throws_ok { $check->execute() } qr/input_files array cannot be empty/,
    'error when no input files are found';

  my $dir = tempdir( CLEANUP => 1 );
  my @dirs = map { join q[/], $dir, $_} qw/a b c d f/;
  map { mkdir $_ } @dirs;
  my @data_dirs = @dirs;
  pop @data_dirs;
  my @files = sort map { join q[/], $_, 'some.spatial_filter.stats'} @data_dirs;
  for my $f (@files) {
    open my $fh, '>', $f or die 'Cannnot open file';
    print $fh 'some';
    close $fh;
  }

  $check = npg_qc::autoqc::checks::spatial_filter->new(rpt_list=>'2549:2', qc_in => \@dirs);
  is_deeply ($check->input_files, \@files, 'input files found');

  lives_ok {$check->result} 'can create result object';
  is ($check->result->path, $dirs[0], 'first path captured');
}

1;
