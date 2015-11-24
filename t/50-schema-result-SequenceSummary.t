use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;
use File::Temp qw/ tempdir /;
use Archive::Extract;
use Perl6::Slurp;
use JSON;
use List::MoreUtils qw/uniq/;
use npg_testing::db;

use_ok('npg_qc::Schema::Result::SequenceSummary');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

my $tempdir = tempdir( CLEANUP => 1);
my $archive = '17448_1_9';
my $ae = Archive::Extract->new(archive => "t/data/autoqc/bam_flagstats/${archive}.tar.gz");
$ae->extract(to => $tempdir) or die $ae->error;
$archive = join q[/], $tempdir, $archive, 'qc', 'all_json';

my $ss_rs = $schema->resultset('SequenceSummary');
my $ss_rc = $ss_rs->result_class;

sub _get_data {
  my $file_name = shift;
  my $json = slurp join(q[/], $archive, $file_name);
  my $values = from_json($json);
  foreach my $key (keys %{$values}) {
    if (!$ss_rc->has_column($key)) {
      delete $values->{$key};
    }
  }
  return $values;
}

subtest 'load the same data twice' => sub {
  plan tests => 13;

  my $values =  _get_data('17448_1#9.sequence_summary.json');
  my $fk_row = $schema->resultset('SeqComposition')->create({digest => '45678', size => 2});

  my $object = $ss_rs->new_result($values);
  isa_ok($object, 'npg_qc::Schema::Result::SequenceSummary');
  throws_ok {$object->insert()}
    qr/NOT NULL constraint failed: sequence_summary\.id_seq_composition/,
    'foreign key referencing the composition table absent - error';

  $object->id_seq_composition($fk_row->id_seq_composition);
  lives_ok { $object->insert() } 'insert with fk is ok';
  my $rs = $ss_rs->search({});
  is ($rs->count, 1, q[one row created in the table]);
  my $row = $rs->next;
  foreach my $column ( sort keys %{$values} ) {
    is ($row->$column, $values->{$column}, "$column retrieved correctly");
  }
  is ($row->iscurrent, 1, 'row is current');
  ok ($row->date, 'date is set');

  $object = $ss_rs->new_result($values);
  $object->id_seq_composition($fk_row->id_seq_composition);
  $object->insert();

  my @rows = $ss_rs->search({})->all();
  is (scalar @rows, 2, 'two rows');
  is ((uniq map { $_->iscurrent } @rows)[0], 1, 'both rows are current');
};


1;


