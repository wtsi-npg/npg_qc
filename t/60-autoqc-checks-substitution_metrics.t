use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;
use File::Temp qw( tempdir );
use File::Copy::Recursive qw(dircopy);
use Perl6::Slurp;
use JSON;

my $tempdir = tempdir(CLEANUP => 1);

use_ok ('npg_qc::autoqc::checks::substitution_metrics');

my $data_dir = join q[/], $tempdir, 'substitution_metrics';
dircopy('t/data/autoqc/substitution_metrics', $data_dir) or die 'Failed to copy';

sub _prune_result_hash {
  my $result = shift;
  my %to_remove =
    map { $_ => 1 }
    qw/__CLASS__ info path/;
  foreach my $key (keys %{$result}) {
    ($to_remove{$key} or $key =~ /\A_/ ) and delete $result->{$key};
  }
}

subtest 'test attributes and simple methods' => sub {
  plan tests => 4;

  my $c = npg_qc::autoqc::checks::substitution_metrics->new(
   tag_index => 1,
   position  => 3,
   id_run    => 44918);
  isa_ok ($c, 'npg_qc::autoqc::checks::substitution_metrics');
  is($c->subset, undef, 'subset field is not set');
  
  $c = npg_qc::autoqc::checks::substitution_metrics->new(
    tag_index => 1,
    position  => 3,
    id_run    => 44918,
    subset    => 'yhuman');
  is ($c->subset, 'yhuman', 'subset attr is set correctly');

  my $json = $c->result()->freeze();
  like ($json, qr/\"subset\":\"yhuman\"/, 'subset field is serialized');
};

subtest 'high-level parsing' => sub {
  plan tests => 3;

  my $stat = "$data_dir/44918_3#1.substitution_metrics.txt";
  my $cram = "$data_dir/44918_3#1.cram";
  open my $fh, '>', $cram or die "Failed to open $cram: $!\n";
  close $fh;

  my $c = npg_qc::autoqc::checks::substitution_metrics->new(
    tag_index => 1,
    position  => 3,
    id_run    => 44918,
    qc_in     => $data_dir,
  );

  my $expected = from_json(
   slurp qq{$data_dir/44918_3#1.substitution_metrics.json}, {chomp=>1});
  $expected->{'path'} = $data_dir;

  lives_ok { $c->execute() } 'execute method is ok';
  my $r;
  my $result_json;
  lives_ok {
    $r = $c->result();
    $result_json = $r->freeze();
    $r->store(qq{$tempdir/44918_3#1.substitution_metrics.json});
  } 'no error when serializing to json string and file';
  
  my $from_json_hash = from_json($result_json);
  is_deeply(_prune_result_hash($from_json_hash), _prune_result_hash($expected), 
    'correct json output');

};

subtest 'high-level parsing, subset' => sub {
  plan tests => 3;

  my $stat = "$data_dir/44918_3#1_yhuman.substitution_metrics.txt";
  my $cram = "$data_dir/44918_3#1_yhuman.cram";
  open my $fh, '>', $cram or die "Failed to open $cram: $!\n";
  close $fh;

  my $c = npg_qc::autoqc::checks::substitution_metrics->new(
    tag_index     => 1,
    position      => 3,
    id_run        => 44918,
    qc_in         => $data_dir,
    filename_root => '44918_3#1_yhuman',
    subset        => 'yhuman',
  );

  my $expected = from_json(
   slurp qq{$data_dir/44918_3#1_yhuman.substitution_metrics.json}, {chomp=>1});
  $expected->{'path'} = $data_dir;

  lives_ok { $c->execute() } 'execute method is ok';
  my $r;
  my $result_json;
  lives_ok {
    $r = $c->result();
    $result_json = $r->freeze();
    $r->store(qq{$tempdir/44918_3#1_yhuman.substitution_metrics.json});
  } 'no error when serializing to json string and file';
  
  my $from_json_hash = from_json($result_json);
  is_deeply(_prune_result_hash($from_json_hash), _prune_result_hash($expected), 
    'correct json output');
};

subtest 'finding files, calculating metrics' => sub {
  plan tests => 12;

  my $fproot = $data_dir .q{/44918_3#1};
  my $cram   = $fproot .'.cram';
  open my $fh, '>', $cram or die "Failed to open $cram : $!\n";
  close $fh;

  my $r1 = npg_qc::autoqc::checks::substitution_metrics->new(
    id_run           => 44918,
    position         => 3,
    tag_index        => 1,
    input_files      => [$fproot . '.cram'],
  );
  my $r2 = npg_qc::autoqc::checks::substitution_metrics->new(
    rpt_list         => '44918:3:1',
    input_files      => [$fproot . '.cram'],
  );

  for my $r (($r1, $r2 )) {
    is($r->_file_path_root, $fproot, 'file path root');
    is($r->substitution_metrics_file,  $fproot . '.substitution_metrics.txt',
       'substitution metrics file found');

    $r->execute();

    my $j;
    lives_ok { $j = $r->result()->freeze } 'serialization to json is ok';
    
    like($j, qr/npg_tracking::glossary::composition/,
        'serialized object contains composition info');
    like($j, qr/npg_tracking::glossary::composition::component::illumina/,
        'serialized object contains component info');
  }

  my $fproot2 = $data_dir .q{/44938_1#1};
  my $cram2   = $fproot2 .'.cram';
  open my $fh2, '>', $cram2 or die "Failed to open $cram2 : $!\n";
  close $fh2;

  my $r3 = npg_qc::autoqc::checks::substitution_metrics->new(
    id_run           => 44938,
    position         => 1,
    tag_index        => 1,
    input_files      => [$fproot2 . '.cram'],
    subset           => 'yhuman'
  );
  $r3->execute();

  my $j3;
  lives_ok { $j3 = $r3->result()->freeze }
    'dont croak when substitution metrics input file does not exist';
  like($j3, qr/substituion metrics input file not found/,
    'serialized object contains file not found comment');

};

1;
