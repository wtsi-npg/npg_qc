use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;
use File::Temp qw/ tempdir /;
use Cwd qw/getcwd abs_path/;
use Archive::Extract;
use Perl6::Slurp;
use JSON;
use npg_testing::db;

use_ok('npg_qc::Schema::Result::RnaSeqc');


my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

my $tempdir = tempdir( CLEANUP => 1);
my $repos = getcwd . q[/t/data/autoqc/rna_seqc];
my $archive = join q[/], $repos, q[data];

my $rs = $schema->resultset('RnaSeqc');
my $rc = $rs->result_class;

sub _get_data {
  my $file_name = shift;
  my $json = slurp join(q[/], $archive, $file_name);
  my $values = from_json($json);
  foreach my $key (keys %{$values}) {
    if (!$rc->has_column($key)) {
      delete $values->{$key};
    }
  }
  return $values;
}

subtest 'load results with a composition fk' => sub {
  plan tests => 4;

  my $values =  _get_data('18407_1#7.rna_seqc.json');
  my $fk_row = $schema->resultset('SeqComposition')->create({digest => '45678', size => 2});

  my $object = $rs->new_result($values);
  isa_ok($object, 'npg_qc::Schema::Result::RnaSeqc');
  throws_ok {$object->insert()}
    qr/NOT NULL constraint failed: rna_seqc.id_seq_composition/,
    'foreign key referencing the composition table absent - error';

  $object->id_seq_composition($fk_row->id_seq_composition);
  lives_ok { $object->insert() } 'insert with fk is ok';
  my $a_rs = $rs->search({});
  is ($a_rs->count, 1, q[one row created in the table]);
};

1;