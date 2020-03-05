use strict;
use warnings;
use Test::More tests => 21;
use Test::Exception;
use File::Temp qw/tempdir/;

use_ok ('npg_qc::autoqc::autoqc');

{
  my $dir = tempdir( CLEANUP => 1 );

  @ARGV = qw/--qc_in t --id_run 4 --position 1/;
  my $factory = npg_qc::autoqc::autoqc->new_with_options(check => 'qX_yield');
  isa_ok($factory, 'npg_qc::autoqc::autoqc');
  is($factory->check, 'qX_yield', 'check attr is set');
  my $check = $factory->create_check_object();
  isa_ok($check, 'npg_qc::autoqc::checks::qX_yield');
  is($check->id_run, 4, 'run id');
  is($check->position, 1, 'position');
  is($check->tag_index, undef, 'tag index');
  is($check->qc_in, 't', 'dir in is set');

  push @ARGV, qw/--tag_index 0 --qc_out/;
  push @ARGV, $dir;
  $factory = npg_qc::autoqc::autoqc->new_with_options(check => 'qX_yield');
  $check = $factory->create_check_object();
  is($check->id_run, 4, 'run id');
  is($check->position, 1, 'position');
  is($check->tag_index, 0, 'tag index');
  is($check->qc_out->[0], $dir, 'dir out is set');

  @ARGV = qw( 
    --qc_in       t
    --id_run      4
    --position    1
    --tag_index   5
    --tmp_path    t
    --file_type   cram
    --input_files t/data/autoqc/090721_IL29_2549/data/2549_1_1.fastqcheck
    --input_files t/data/autoqc/090721_IL29_2549/data/2549_1_1.fastqcheck
  );
  $factory = npg_qc::autoqc::autoqc->new_with_options(check => 'qX_yield');
  $check = $factory->create_check_object();
  is($check->id_run, 4, 'run id');
  is($check->position, 1, 'position');
  is($check->tag_index, 5, 'tag index');
  is($check->qc_in, 't', 'dir in is set');
  is($check->tmp_path, 't', 'temporary path is set');
  is($check->file_type, 'cram', 'file type is set');
  is(join(q[ ], @{$check->input_files}),
    't/data/autoqc/090721_IL29_2549/data/2549_1_1.fastqcheck ' .
    't/data/autoqc/090721_IL29_2549/data/2549_1_1.fastqcheck',
    'input files array is set');

  @ARGV = qw(--id_run 4 --position 1 --qc_out);
  push @ARGV, $dir;
  $factory = npg_qc::autoqc::autoqc->new_with_options(check => 'check');
  lives_ok { $check = $factory->create_check_object() } 'qc_in is optional';
  is($check->qc_out->[0], $dir, 'dir out is set');   
}

1;
