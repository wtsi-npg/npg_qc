use strict;
use warnings;
use Test::More tests => 17;
use Test::Exception;
use JSON;
use Moose::Meta::Class;

use npg_testing::db;
use t::autoqc_util;

use_ok('npg_qc::Schema::Result::InsertSize');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

my $table = 'InsertSize';

{
  my $json = q { 
  {"min_isize":81,"quartile1":142,
  "num_well_aligned_reads":9898,"median":166,"bin_width":4,"reference":"/lustre/scratch109/srpipe/references/Homo_sapiens/1000Genomes_hs37d5/all/bwa/hs37d5.fa","paired_reads_direction_in":1,
  "info":{"Additional_Modules":"npg_qc::autoqc::parse::alignment 16446;npg_common::extractor::fastq 15996;npg_common::Alignment 16554;FASTX Toolkit fastx_reverse_complement 0.0.13","Check":"npg_qc::autoqc::checks::insert_size","Aligner":"bwa","Aligner_version":"0.5.9-r16","Check_version":"16569"},
  "num_well_aligned_reads_opp_dir":82,"pass":"1",
  "sample_size":"10000",
  "expected_size":["100","400"],"std":34,
  "path":"/nfs/sf19/ILorHSany_sf19/analysis/130125_HS23_09225_B_C1CBDACXX/Data/Intensities/BAM_basecalls_20130203-192218/PB_cal_bam/archive/lane1","mean":173,
  "id_run":"9225",
  "position":"1",
  "tag_index":"93",
  "quartile3":196,
  "bins":[1,7,3,15,28,40,83,104,155,223,229,281,355,386,426,418,452,414,381,407,421,407,407,344,349,289,283,284,257,229,197,191,157,181,169,132,124,113,100,88,68,80,68,64,65,53,37,37,32,37,21,19,23,25,9,20,12,17,12,10,9,9,3,4,6,5,3,0,3,3,1,0,2,1,2,1,0,2,0,1,0,3,1],
  "filenames":["9225_1_1#93.fastq","9225_1_2#93.fastq"]}
  };

  my $values = from_json($json);
  $values->{'id_seq_composition'} =
    t::autoqc_util::find_or_save_composition($schema,
    {id_run => 9225, position => 1, tag_index => 93});
  my $object = $schema->resultset($table)->new_result($values);
  isa_ok($object, 'npg_qc::Schema::Result::InsertSize');
  lives_ok {$object->insert()} 'creating a row in the database lives';

  my $rs = $schema->resultset($table)->search({});
  is ($rs->count, 1, q[one row created in the table]);

  my $row = $rs->next;
  is ($row->tag_index, 93, q[tag index retrieved correctly from the table]);
  my $expected_info = {"Additional_Modules"=>"npg_qc::autoqc::parse::alignment 16446;npg_common::extractor::fastq 15996;npg_common::Alignment 16554;FASTX Toolkit fastx_reverse_complement 0.0.13","Check"=>"npg_qc::autoqc::checks::insert_size","Aligner"=>"bwa","Aligner_version"=>"0.5.9-r16","Check_version"=>"16569" };
  is (ref $row->info, 'HASH', 'info retrieved as a hash');
  is_deeply ($row->info, $values->{'info'}, q[info deeply compared after retrieval from the table]);
  foreach my $col (qw( bins expected_size filenames )) {
    is (ref $row->$col, 'ARRAY', qq[$col retrieved as an array]);
  }

  my %values1 = %{$values};
  my $v1 = \%values1; 
  delete $v1->{'id_run'};
  delete $v1->{'position'};
  delete $v1->{'tag_index'};
  my $row1;
  lives_ok {$row1 = $rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()}
    'another or the same row?';
  is ($row->id_insert_size, $row1->id_insert_size, 'new row is not created');

  %values1 = %{$values};
  $v1 = \%values1;
  delete $v1->{'id_run'};
  delete $v1->{'position'};
  delete $v1->{'tag_index'};
  $v1->{'id_seq_composition'} =
    t::autoqc_util::find_or_save_composition($schema,
    {id_run => 9225, position => 1, tag_index => 95});
  lives_ok {$row1 = $rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()}
    'a row is created';
  isnt ($row->id_insert_size, $row1->id_insert_size, 'new row is created');
  is ($row1->id_run, undef, 'id run value is undefined');
  is ($row1->position, undef, 'position value is undefined');
  is ($row1->tag_index, undef, 'tag_index value is undefined'); 
}

1;


