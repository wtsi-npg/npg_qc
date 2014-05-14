use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;
use Test::Deep;
use Moose::Meta::Class;
use JSON;
use npg_testing::db;

use_ok('npg_qc::Schema::Result::Contamination');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

{
  my $json = '{
"position":"1",
"genome_factor":{"Streptococcus_equi":"1.00","Danio_rerio":"19.26","Escherichia_coli":"1.00","Mycobacterium_tuberculosis":"1.00","Homo_sapiens":"12.46","Human_herpesvirus_4":"1.00","Clostridium_difficile":"1.00","Staphylococcus_aureus":"1.00","Leishmania_major":"12.25","Plasmodium_falciparum":"7.07","PhiX":"1.00","Mus_musculus":"13.46"},
"path":"/staging/IL37/analysis/091113_IL37_4056/Data/Intensities/Bustard1.5.1_23-11-2009_RTA/GERALD_23-11-2009_RTA/archive",
"read_count":0,
"id_run":"4056",
"reference_version":"Composite_20091109",
"aligner_version":"Bowtie 0.11.3",
"contaminant_count":{"Streptococcus_equi":0,"Danio_rerio":0,"Escherichia_coli":0,"Mycobacterium_tuberculosis":0,"Human_herpesvirus_4":0,"Homo_sapiens":0,"Staphylococcus_aureus":0,"Clostridium_difficile":0,"Leishmania_major":0,"Plasmodium_falciparum":0,"Mus_musculus":0,"PhiX":0}}';

  my $values = from_json($json);
  my $rs = $schema->resultset('Contamination');
  isa_ok($rs->new($values), 'npg_qc::Schema::Result::Contamination');
  $rs->result_class->deflate_unique_key_components($values);
  is($values->{'tag_index'}, -1, 'tag index deflated correctly');

  my %original_values = %{$values};

  lives_ok {$rs->find_or_new($values)->set_inflated_columns($values)->update_or_insert()} 'lane record inserted';
  my $rs1 = $rs->search({});
  is ($rs1->count, 1, q[one row created in the table]);  
  my $row = $rs1->next;
  is($row->tag_index, undef, 'tag index inflated correctly');
  is(ref $row->contaminant_count, 'HASH', 'contaminant_count column value returned as a hash');
 
  cmp_deeply($row->contaminant_count, $original_values{'contaminant_count'},
    'contaminant_count ref hash content is correct');
}
1;


