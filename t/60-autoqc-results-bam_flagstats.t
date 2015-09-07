use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;
use Test::Warn;
use Test::Deep;
use File::Temp qw/ tempdir /;
use Perl6::Slurp;
use JSON;
use Compress::Zlib;
use Archive::Extract;

my $tempdir = tempdir( CLEANUP => 1);

subtest 'test attributes and simple methods' => sub {
  plan tests => 20;

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
  ok(!$r->has_subset, 'subset attr is not set');
  $r->_set_subset('human');
  ok($r->has_subset, 'subset attr is set');
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
    load('t/data/autoqc/bam_flagstats/4921_3_bam_flagstats.json');
  ok( !$r->total_reads(), 'total reads not available' ) ;
};

subtest 'high-level parsing' => sub {
  plan tests => 15;

  my $package = 'npg_qc::autoqc::results::bam_flagstats';
  my $dups  = 't/data/autoqc/bam_flagstats/4783_5_metrics_optical.txt';
  my $fstat = 't/data/autoqc/bam_flagstats/4783_5.flagstat';
  my $dups_attr_name    = 'markdups_metrics_file';
  my $fstat_attr_name   = 'flagstats_metrics_file';
  my $stats_attr_name   = 'samtools_stats_file';

  my $h1 = {position => 5, id_run   => 4783};
  $h1->{$dups_attr_name}    = $dups;
  $h1->{$fstat_attr_name}   = $fstat;
  my $r = $package->new($h1);

  my $expected = from_json(
    slurp q{t/data/autoqc/bam_flagstats/4783_5_bam_flagstats.json}, {chomp=>1});
  $expected->{'related_objects'} = [];

  lives_ok { $r->execute() } 'execute method is ok';
  my $result_json;
  lives_ok {
    $result_json = $r->freeze();
    $r->store(qq{$tempdir/4783_5_bam_flagstats.json});
  } 'no error when serializing to json string and file';

  my $from_json_hash = from_json($result_json);
  delete $from_json_hash->{__CLASS__};
  delete $from_json_hash->{$dups_attr_name};
  delete $from_json_hash->{$fstat_attr_name};
  delete $from_json_hash->{'fully_build_related'};
   
  is_deeply($from_json_hash, $expected, 'correct json output');
  is($r->total_reads(), 32737230 , 'total reads');
  is($r->total_mapped_reads(), '30992462', 'total mapped reads');
  is($r->percent_mapped_reads, 94.6703859795102, 'percent mapped reads');
  is($r->percent_duplicate_reads, 15.6023713120952, 'percent duplicate reads');
  is($r->percent_properly_paired ,89.7229484595978, 'percent properly paired');
  is($r->percent_singletons, 2.92540938863795, 'percent singletons');
  is($r->read_pairs_examined(), 15017382, 'read_pairs_examined');
  

  delete $h1->{$dups_attr_name};
  delete $h1->{$fstat_attr_name};
  $r = $package->new($h1);
  warning_like {$r->samtools_stats_file}
    qr/Sequence file not given - not looking for samtools stats files/,
    'warning when looking for samtool stats files';
  is_deeply($r->samtools_stats_file, {}, 'samtools stats files not found');
  is($r->markdups_metrics_file, undef, 'markdups metrics not found');
  is($r->flagstats_metrics_file, undef, 'flagstats metrics not found');
  throws_ok { $r->execute() } qr/markdups_metrics_file not found/,
    'no input file - execute fails';
};

my $archive_16960 = '16960_1_0';
my $ae_16960 = Archive::Extract->new(archive => "t/data/autoqc/bam_flagstats/${archive_16960}.tar.gz");
$ae_16960->extract(to => $tempdir) or die $ae_16960->error;
$archive_16960 = join q[/], $tempdir, $archive_16960;

subtest 'finding files, calculating metrics' => sub {
  plan tests => 12;

  my $fproot = $archive_16960 . '/16960_1#0';
  my $r = npg_qc::autoqc::results::bam_flagstats->new(
    id_run              => 16960,
    position            => 1,
    tag_index           => 0,
    sequence_file       => $fproot . '.bam',
    fully_build_related => 0,
  );

  is($r->_file_path_root, $fproot, 'file path root');
  is($r->filename_root, undef, 'filename root undefined');
  is($r->filename4serialization, '16960_1#0.bam_flagstats.json',
    'filename for serialization'); 
  is($r->markdups_metrics_file,  $fproot . '.markdups_metrics.txt',
    'markdups metrics found');
  is($r->flagstats_metrics_file, $fproot . '.flagstat',
    'flagstats metrics found');
  warning_like { $r->samtools_stats_file() } qr/Found the following samtools stats files/,
   'successfully finding stats files';

  my $stats_files = {
     'F0x900' => $fproot . '_F0x900.stats',
     'F0xB00' => $fproot . '_F0xB00.stats',               };
  is_deeply($r->samtools_stats_file, $stats_files, 'stats files are correct');
 
  $r->execute();
  is($r->library_size, 240428087, 'library size value');
  is($r->mate_mapped_defferent_chr, 8333632, 'mate_mapped_defferent_chr value');
  my $j;
  lives_ok { $j=$r->freeze } 'serialization to json is ok';
  unlike($j, qr/_file_path_root/, 'serialization does not contain excluded attr');

  $r = npg_qc::autoqc::results::bam_flagstats->new(
    id_run              => 16960,
    position            => 1,
    tag_index           => 0,
    sequence_file       => $fproot . '.bam',
  );
  my $bam_md5 = join q[.], $r->sequence_file, 'md5';
  throws_ok {$r->execute}
    qr{Can't open '$bam_md5'},
    'error calling execute() on related objects';
};

subtest 'finding phix subset files (no run id)' => sub {
  plan tests => 11;

  my $fproot = $archive_16960 . '/16960_1#0_phix';
  my $r = npg_qc::autoqc::results::bam_flagstats->new(
    subset              => 'phix',
    sequence_file       => $fproot . '.bam',
    fully_build_related => 0,
  );

  lives_ok {$r->execute} 'metrics parsing ok';
  is($r->library_size, 691461, 'library size value');
  is($r->mate_mapped_defferent_chr, 0, 'mate_mapped_defferent_chr value');

  is($r->_file_path_root, $fproot, 'file path root');
  is($r->filename_root, '16960_1#0', 'filename root');
   is($r->filename4serialization, '16960_1#0_phix.bam_flagstats.json',
    'filename for serialization');  
  is($r->markdups_metrics_file, $fproot . '.markdups_metrics.txt',
    'phix markdups metrics found');
  is($r->flagstats_metrics_file, $fproot . '.flagstat',
    'phix flagstats metrics found');
  warning_like { $r->samtools_stats_file() } qr/Found the following samtools stats files/,
   'successfully finding stats files';

  my $stats_files = {
     'F0x900' => $fproot . '_F0x900.stats',
     'F0xB00' => $fproot . '_F0xB00.stats',
                     };
  is_deeply($r->samtools_stats_file, $stats_files, 'phix stats files found');
  lives_ok { $r->freeze } 'no run id - serialization to json is ok';
};

subtest 'full functionality with full file sets' => sub {
  plan tests => 16;

  my $archive = '17448_1_9';
  my $ae = Archive::Extract->new(archive => "t/data/autoqc/bam_flagstats/${archive}.tar.gz");
  $ae->extract(to => $tempdir) or die $ae->error;
  $archive = join q[/], $tempdir, $archive;

  my $fproot = $archive . '/17448_1#9';
  my $sfile = $fproot . '.cram';
  my $composition_digest = 'bfc10d33f4518996db01d1b70ebc17d986684d2e04e20ab072b8b9e51ae73dfa';

  my $r = npg_qc::autoqc::results::bam_flagstats->new(
    id_run        => 17448,
    position      => 1,
    tag_index     => 9,
    sequence_file => $sfile,
    fully_build_related => 0,
  );

  $r->execute();
  ok ($r->_has_related_objects, 'related object array has been set');
  my @ros = @{$r->related_objects};
  is (scalar @ros, 3, 'three related objects');

  my @filters = qw/F0x900 F0xB00/;
  my $i = 0;
  while ($i < 2) {
    my $ro = $ros[$i];
    my $filter = $filters[$i];
    isa_ok ($ro, 'npg_qc::autoqc::results::samtools_stats');
    is ($ro->filter, $filter, 'correct filter');
    is ($ro->stats_file, $fproot . q[_] . $filter . '.stats', 'stats file path');
    isa_ok ($ro->composition, 'npg_tracking::glossary::composition');
    is ($ro->composition_digest, $composition_digest, 'composition digest');
    $i++;
  }

  my $ro = $ros[2];
  isa_ok ($ro, 'npg_qc::autoqc::results::sequence_summary');
  is ($ro->sequence_file, $sfile, 'seq file path');
  isa_ok ($ro->composition, 'npg_tracking::glossary::composition');
  is ($ro->composition_digest, $composition_digest, 'composition digest');
};

1;
