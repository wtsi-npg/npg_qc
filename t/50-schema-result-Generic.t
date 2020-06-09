use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;
use JSON;
use Moose::Meta::Class;

use npg_testing::db;
use t::autoqc_util;

use_ok('npg_qc::Schema::Result::Generic');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

{
  my $json = q(
{
  "desc": "ncov2019-artic-nf",
  "doc": {
    "QC summary": {
      "bam": "34107_2#96.mapped.primertrimmed.sorted.bam",
      "fasta": "34107_2#96.primertrimmed.consensus.fa",
      "longest_no_N_run": "1",
      "num_aligned_reads": "4",
      "pct_N_bases": "100.00",
      "pct_covered_bases": "0.00",
      "qc_pass": "FALSE",
      "sample_name": "34107_2#96"
    },
    "meta": {
      "num_input_reads": "18666",
      "sample_type": "NEG_CONTROL",
      "supplier_sample_name": "CGAP-1E5D90"
    }
  },
  "info": {
    "Check": "npg_qc::autoqc::checks::generic",
    "Check_version": "0",
    "Pipeline_name": "ncov2019-artic-nf",
    "Script_name": "npg_autoqc_generic4artic",
    "Script_version": "0"
  }
}

              );

  my $values = from_json($json);

  $values->{'id_seq_composition'} =
    t::autoqc_util::find_or_save_composition($schema,
    {id_run => 34107, position => 2, tag_index => 96});
  my $object = $schema->resultset('Generic')->new_result($values);
  isa_ok($object, 'npg_qc::Schema::Result::Generic');
  lives_ok {$object->insert()} 'creating a row in the database';

  my $rs = $schema->resultset('Generic')->search({});
  is ($rs->count, 1, 'one row is created');
  my $row = $rs->next;
  is ($row->desc, 'ncov2019-artic-nf', 'pipeline description');
  is_deeply ($row->info, $values->{'info'}, 'info retrieved as hash ref');
  is_deeply ($row->doc, $values->{'doc'}, 'doc retrieved as hash ref');

  $values->{'desc'} = 'another pipeline';
  $schema->resultset('Generic')->create($values);
  $rs = $schema->resultset('Generic')->search({});
  is ($rs->count, 2, 'a new row is created in the table for the same composition');
}

1;


