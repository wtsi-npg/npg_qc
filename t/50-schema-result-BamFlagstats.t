use strict;
use warnings;
use Test::More tests => 17;
use Test::Exception;
use Test::Deep;
use Moose::Meta::Class;
use JSON;
use npg_testing::db;

use_ok('npg_qc::Schema::Result::BamFlagstats');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

my $json = 
q { 

{"paired_mapped_reads":6574850,"percent_duplicate":0.087512,
  "unpaired_read_duplicates":7797,
  "position":"1",
  "library":"6394913",
  "paired_read_duplicates":572827,
  "library_size":35532776,
  "info":{"Picard_metrics_header":"## net.sf.picard.metrics.StringHeader\n# net.sf.picard.sam.MarkDuplicates INPUT=[/nfs/sf19/ILorHSany_sf19/analysis/130125_HS23_09225_B_C1CBDACXX/Data/Intensities/BAM_basecalls_20130203-192218/PB_cal_bam/archive/lane1/_HDvBT2csg/sorted.bam] OUTPUT=/dev/stdout METRICS_FILE=/tmp/A7VlclA6ay REMOVE_DUPLICATES=false ASSUME_SORTED=true MAX_FILE_HANDLES_FOR_READ_ENDS_MAP=900 READ_NAME_REGEX=[a-zA-Z0-9_]+:[0-9]:([0-9]+):([0-9]+):([0-9]+).* VERBOSITY=ERROR VALIDATION_STRINGENCY=SILENT COMPRESSION_LEVEL=0    MAX_SEQUENCES_FOR_DISK_READ_ENDS_MAP=50000 SORTING_COLLECTION_SIZE_RATIO=0.25 OPTICAL_DUPLICATE_PIXEL_DISTANCE=100 QUIET=false MAX_RECORDS_IN_RAM=500000 CREATE_INDEX=false CREATE_MD5_FILE=false\n## net.sf.picard.metrics.StringHeader\n# Started on: Tue Feb 05 05:46:57 GMT 2013\n","Samtools":"0.1.18 (r982:295)","Picard-tools":"1.72"},
  "mate_mapped_defferent_chr":15868,
  "unmapped_reads":379198,
  "read_pairs_examined":6574850,
  "id_run":"9225",
  "unpaired_mapped_reads":30784,
  "tag_index":"0",
  "num_total_reads":13559682,
  "proper_mapped_pair":13124312,
  "read_pair_optical_duplicates":457,
  "mate_mapped_defferent_chr_5":11929
  }
};

my $rs = $schema->resultset('BamFlagstats');

{
  my $values = from_json($json);
  isa_ok($rs->new($values), 'npg_qc::Schema::Result::BamFlagstats');
  my %values1 = %{$values};
  my $v1 = \%values1;

  $rs->result_class->deflate_unique_key_components($v1);
  is($v1->{'tag_index'}, 0, 'tag index zero not deflated');
  is($v1->{'human_split'}, 'all', 'human_split correctly deflated');
  lives_ok {$rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()} 'lane record inserted';
  my $rs1 = $rs->search({});
  is ($rs1->count, 1, q[one row created in the table]);
  my $row = $rs1->next;
  is($row->tag_index, 0, 'tag index retrieved correctly');
  is($row->human_split, undef, 'human_split retrieved as undef');
  is($row->subset, undef, 'subset retrieved as undef');
  is(ref $row->info, 'HASH', 'info returned as a hash ref');
  cmp_deeply($row->info, $values->{'info'},
    'info hash ref content is correct');
}

{
  my $json = '{"histogram":{},"human_split":"phix","id_run":"12287","info":{"Picard-tools":"1.72(1230)","Picard_metrics_header":"# /software/hpag/biobambam/0.0.76/bin/bammarkduplicates I=/nfs/sf54/ILorHSany_sf54/analysis/140227_HS35_12287_A_H8M6LADXX/Data/Intensities/BAM_basecalls_20140228-082452/no_cal/archive/lane1/HJH8I0e3i9/sorted.bam O=/dev/stdout tmpfile=/nfs/sf54/ILorHSany_sf54/analysis/140227_HS35_12287_A_H8M6LADXX/Data/Intensities/BAM_basecalls_20140228-082452/no_cal/archive/lane1/HJH8I0e3i9/ M=/tmp/Kr78slLXuv level=0\n","Samtools":"0.1.18 (r982:295)"},"library":"9418068",
"library_size":-1,
"mate_mapped_defferent_chr":0,"mate_mapped_defferent_chr_5":0,"num_total_reads":2,"paired_mapped_reads":1,"paired_read_duplicates":0,"percent_duplicate":0,"position":"1","proper_mapped_pair":2,"read_pair_optical_duplicates":0,"read_pairs_examined":1,"tag_index":"89","unmapped_reads":0,"unpaired_mapped_reads":0,"unpaired_read_duplicates":0,"subset":"target"}';

  my $v = from_json($json);
  $rs->result_class->deflate_unique_key_components($v);
  is ($v->{'library_size'}, undef, 'library size converted to undef');
  lives_ok {$rs->find_or_new($v)->set_inflated_columns($v)->update_or_insert()} 'record inserted';
  my $row = $rs->search({id_run=>12287, position=>1, tag_index=>89,})->next;
  is ($row->library_size, undef, 'library size retrieved as undef');
  is ($row->subset, undef, 'subset retrieved as undef');

  $v->{'subset'} = 'human';
  $v->{'tag_index'} = 88;
  lives_ok {$rs->find_or_new($v)->set_inflated_columns($v)->update_or_insert()} 'record updated';
  $row = $rs->search({id_run=>12287, position=>1, tag_index=>88,})->next;
  is ($row->subset, 'human', 'subset is human');
}

1;
