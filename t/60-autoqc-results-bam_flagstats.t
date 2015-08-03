use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use Test::Warn;
use Test::Deep;
use File::Temp qw/ tempdir /;
use Perl6::Slurp;
use JSON;
use Compress::Zlib;

subtest 'test attributes and simple methods' => sub {
  plan tests => 18;

  use_ok ('npg_qc::autoqc::results::bam_flagstats');

  my $r = npg_qc::autoqc::results::bam_flagstats->new(
            position => 5,
            id_run   => 4783);
  isa_ok ($r, 'npg_qc::autoqc::results::bam_flagstats');
  is($r->check_name(), 'bam flagstats', 'correct check name');
  is($r->filename4serialization(), '4783_5.bam_flagstats.json',
      'default file name');
  is($r->human_split, undef, 'human_split field is not set');
  is($r->subset, undef, 'subset field is not set');
  $r->human_split('human');
  is($r->check_name(), 'bam flagstats', 'check name has not changed');
  $r->subset('human');
  is($r->check_name(), 'bam flagstats human', 'check name has changed');
  is($r->filename4serialization(), '4783_5_human.bam_flagstats.json',
      'file name contains "human" flag');

  $r = npg_qc::autoqc::results::bam_flagstats->new(
            position => 5,
            id_run   => 4783,
            human_split => 'phix');
  is ($r->subset, 'phix', 'subset attr is set correctly');
  my $json = $r->freeze();
  like ($json, qr/\"subset\":\"phix\"/, 'subset field is serialized');
  like ($json, qr/\"human_split\":\"phix\"/, 'human_split field is serialized');

  $r = npg_qc::autoqc::results::bam_flagstats->new(
            position => 5,
            id_run   => 4783,
            subset   => 'phix');
  is ($r->human_split, 'phix', 'human_split attr is set correctly');
  $json = $r->freeze();
  like ($json, qr/\"subset\":\"phix\"/, 'subset field is serialized');
  like ($json, qr/\"human_split\":\"phix\"/, 'human_split field is serialized');

  throws_ok { npg_qc::autoqc::results::bam_flagstats->new(
            position => 5,
            id_run   => 4783,
            subset   => 'phix',
            human_split => 'yhuman')
  } qr/human_split and subset attrs are different: yhuman and phix/,
    'error when human_split and subset attrs are different';

  lives_ok { npg_qc::autoqc::results::bam_flagstats->new(
            position => 5,
            id_run   => 4783,
            subset   => 'yhuman',
            human_split => 'yhuman')
  } 'no error when human_split and subset attrs are consistent';

  $r = npg_qc::autoqc::results::bam_flagstats->
    load('t/data/autoqc/4921_3_bam_flagstats.json');
  ok( !$r->total_reads(), 'total reads not available' ) ;
};

subtest 'low-level parsing' => sub {
  plan tests => 7;

  my $ref = {position => 5, id_run => 4783,};

  my $r = npg_qc::autoqc::results::bam_flagstats->new($ref);
  $r->parsing_metrics_file('t/data/autoqc/estimate_library_complexity_metrics.txt');
  is($r->read_pairs_examined(),2384324, 'read_pairs_examined');
  is($r->paired_mapped_reads(),  0, 'paired_mapped_reads');

  $r = npg_qc::autoqc::results::bam_flagstats->new($ref);
  open my $flagstats_fh2, '<', 't/data/autoqc/6440_1#0.bamflagstats';
  $r->parsing_flagstats($flagstats_fh2);
  close $flagstats_fh2; 
  is($r->total_reads(), 2978224 , 'total reads');
  is($r->proper_mapped_pair(),2765882, 'properly paired');

  $ref->{'tag_index'} = 0;
  $r = npg_qc::autoqc::results::bam_flagstats->new($ref);
  lives_ok {$r->parsing_metrics_file('t/data/autoqc/12313_1#0_bam_flagstats.txt')}
    'file with library size -1 parsed';
  is($r->library_size, undef, 'library size is undefined');
  is($r->read_pairs_examined, 0, 'examined zero read pairs');
};

subtest 'high-level parsing - backwards compatibility' => sub {
  plan tests => 24;

  my $tempdir = tempdir( CLEANUP => 1);
  my $package = 'npg_qc::autoqc::results::bam_flagstats';
  my $dups  = 't/data/autoqc/4783_5_metrics_optical.txt';
  my $fstat = 't/data/autoqc/4783_5_mk.flagstat';
  my $dups_attr_name  = 'markdups_metrics_file';
  my $fstat_attr_name = 'flagstats_metrics_file';
  my $stats_attr_name = 'samtools_stats_file';
  my $h1 = {position => 5,id_run => 4783,};

  my $r1 = $package->new($h1);
  $r1->parsing_metrics_file($dups);

  open my $flagstats_fh, '<', $fstat;
  $r1->parsing_flagstats($flagstats_fh);
  close $flagstats_fh;

  $h1->{$dups_attr_name} = $dups;
  $h1->{$fstat_attr_name} = $fstat;
  my $r2 = $package->new($h1);
  my $expected = from_json(
    slurp q{t/data/autoqc/4783_5_bam_flagstats.json}, {chomp=>1});
  for my $r (($r1, $r2)) {

    # for $r1 the files to parse are not given
    # for $r2 the metrics files are given but the stats files are nor available
    my $w = 'Not looking for samtools stats files';
    if ($r->markdups_metrics_file) {
      $w = 'Not found samtools stats files';
    }
    warning_like { $r->execute() } qr/^$w/, 'execute method warns';
    is(scalar keys %{$r->$stats_attr_name}, 0, 'stats files hash empty');
    lives_and { is scalar @{$r->related_data}, 0} 'no related data';         

    my $result_json;
    lives_ok {
      $result_json = $r->freeze();
      $r->store(qq{$tempdir/4783_5_bam_flagstats.json});
    } 'no error when serializing to json string and file';

    my $from_json_hash = from_json($result_json);
    delete $from_json_hash->{__CLASS__}; 
    delete $from_json_hash->{$dups_attr_name};
    delete $from_json_hash->{$fstat_attr_name};
    delete $from_json_hash->{$stats_attr_name};

    is_deeply($from_json_hash, $expected, 'correct json output');
    is($r->total_reads(), 32737230 , 'total reads');
    is($r->total_mapped_reads(), '30992462', 'total mapped reads');
    is($r->percent_mapped_reads, 94.6703859795102, 'percent mapped reads');
    is($r->percent_duplicate_reads, 15.6023713120952, 'percent duplicate reads');
    is($r->percent_properly_paired ,89.7229484595978, 'percent properly paired');
    is($r->percent_singletons, 2.92540938863795, 'percent singletons');
    is($r->read_pairs_examined(), 15017382, 'read_pairs_examined');
  }
};

subtest 'finding and reading stats files' => sub {
  plan tests => 6;

  my $data_path = 't/data/autoqc/bam_flagstats/';
  my $r = npg_qc::autoqc::results::bam_flagstats->new(
    id_run                 => 16960,
    position               => 1,
    tag_index              => 0,
    markdups_metrics_file  =>
      $data_path . '16960_1#0.markdups_metrics.txt',
    flagstats_metrics_file =>
      $data_path . '16960_1#0.flagstat',
  );

  warning_like { $r->execute() } qr/Found the following samtools stats files/,
   'successfully calling execute() method';

  my $stats_files = {
     'F0x900' => $data_path . '16960_1#0_F0x900.stats',
     'F0xB00' => $data_path . '16960_1#0_F0xB00.stats',
                     };
  is_deeply($r->samtools_stats_file, $stats_files, 'stats files found');
   
  my @related = ();
  push @related, {'relationship_name' => 'samtools_stats',
                  'filter'            => 'F0x900',
                  'file_content'      =>
                   compress("stats file for 16960_1#0_F0x900.stats\n")};
  push @related, {'relationship_name' => 'samtools_stats',
                  'filter'            => 'F0xB00',
                  'file_content'      =>
                  compress("stats file for 16960_1#0_F0xB00.stats\n")};
  is_deeply($r->related_data(), \@related, 'stats files read');

  my $invalid_path = $data_path . '16960_1#0_F0xG00.stats';
  $r->samtools_stats_file->{'F0xB00'} = $invalid_path;
  throws_ok { $r->related_data() }
    qr/Error reading $invalid_path: Can\'t open \'$invalid_path\'/,
    'error reading one of stats files';

 $r = npg_qc::autoqc::results::bam_flagstats->new(
    id_run                 => 16960,
    position               => 1,
    tag_index              => 0,
    flagstats_metrics_file =>
      $data_path . '16960_1#0.flagstat',
  );
  warning_like { $r->execute() } qr/Found the following samtools stats files/,
   'successfully calling execute() method';
  is_deeply($r->samtools_stats_file, $stats_files, 'stats files found');
};

1;
