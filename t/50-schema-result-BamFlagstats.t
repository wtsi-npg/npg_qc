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

my $rs = $schema->resultset('BamFlagstats');

{
  my $json = '{"histogram":{},"id_run":"9225","info":{"Picard-tools":"1.72(1230)","Picard_metrics_header":"# /software/hpag/biobambam/0.0.76/bin/bammarkduplicates I=sorted.bam O=/dev/stdout tmpfile=HJH8I0e3i9/ M=/tmp/Kr78slLXuv level=0\n","Samtools":"0.1.18 (r982:295)"},"library":"9418068",
"library_size":-1,
"mate_mapped_defferent_chr":0,"mate_mapped_defferent_chr_5":0,"num_total_reads":2,"paired_mapped_reads":1,"paired_read_duplicates":0,"percent_duplicate":0,"position":"1","proper_mapped_pair":2,"read_pair_optical_duplicates":0,"read_pairs_examined":1,"tag_index":"0","unmapped_reads":0,"unpaired_mapped_reads":0,"unpaired_read_duplicates":0}';

  my $values = from_json($json);
  isa_ok($rs->new_result($values), 'npg_qc::Schema::Result::BamFlagstats');
  my %values1 = %{$values};
  my $v1 = \%values1;

  $rs->deflate_unique_key_components($v1);
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
  my $json = '{"histogram":{},"human_split":"phix","id_run":"12287","info":{"Picard-tools":"1.72(1230)","Picard_metrics_header":"# /software/hpag/biobambam/0.0.76/bin/bammarkduplicates I=sorted.bam O=/dev/stdout tmpfile=/HJH8I0e3i9/ M=/tmp/Kr78slLXuv level=0\n","Samtools":"0.1.18 (r982:295)"},"library":"9418068",
"library_size":-1,
"mate_mapped_defferent_chr":0,"mate_mapped_defferent_chr_5":0,"num_total_reads":2,"paired_mapped_reads":1,"paired_read_duplicates":0,"percent_duplicate":0,"position":"1","proper_mapped_pair":2,"read_pair_optical_duplicates":0,"read_pairs_examined":1,"tag_index":"89","unmapped_reads":0,"unpaired_mapped_reads":0,"unpaired_read_duplicates":0}';

  my $v = from_json($json);
  $rs->deflate_unique_key_components($v);
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
