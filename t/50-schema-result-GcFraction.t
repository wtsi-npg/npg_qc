use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;
use Test::Deep;
use Moose::Meta::Class;
use JSON;
use npg_testing::db;

use_ok('npg_qc::Schema::Result::GcFraction');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

my $json = 
q { 
{
  "info":{"Check":"npg_qc::autoqc::checks::gc_fraction","Check_version":"16569"},
  "forward_read_gc_percent":45.4,
  "pass":1,
  "threshold_difference":20,
  "position":"1",
  "path":"/nfs/sf19/ILorHSany_sf19/analysis/130125_HS23_09225_B_C1CBDACXX/Data/Intensities/BAM_basecalls_20130203-192218/PB_cal_bam/archive/lane1","ref_count_path":"/lustre/scratch109/srpipe/references/Homo_sapiens/1000Genomes_hs37d5/all/npgqc","id_run":"9225","ref_gc_percent":40.9044893959752,
  "forward_read_filename":"9225_1_1#93.fastqcheck",
  "reverse_read_filename":"9225_1_2#93.fastqcheck",
  "reverse_read_gc_percent":45.5}
};

my $values = from_json($json);
my $rs = $schema->resultset('GcFraction');
isa_ok($rs->new_result($values), 'npg_qc::Schema::Result::GcFraction');

{
  my %values1 = %{$values};
  my $v1 = \%values1;

  $rs->deflate_unique_key_components($v1);
  is($v1->{'tag_index'}, -1, 'tag index deflated');
  lives_ok {$rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()} 'lane record inserted';
  my $rs1 = $rs->search({});
  is ($rs1->count, 1, q[one row created in the table]);
  my $row = $rs1->next;
  is($row->tag_index, undef, 'tag index inflated');
  is(ref $row->info, 'HASH', 'info returned as hash ref');
  cmp_deeply($row->info, $values->{'info'},
    'info hash content is correct');  
}
1;


