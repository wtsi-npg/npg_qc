use strict;
use warnings;
use Test::More tests => 3;
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

subtest 'composition, rpt_key, comparison' => sub {
  plan tests => 16;

  my $fk_row = $schema->resultset('SeqComposition')
    ->search({digest => '45678', size => 2})->next(); 
  my $id_composition = $fk_row->id_seq_composition;
  my $new = $schema->resultset('SeqComponent')->create(
    {id_run => 17448, position => 1, tag_index => 9, digest => 'digest1'});
  my $id_component1 = $new->id_seq_component;
  $new = $schema->resultset('SeqComponent')->create(
    {id_run => 17448, position => 2, tag_index => 9, digest => 'digest2'});
  my $id_component2 = $new->id_seq_component;
  $schema->resultset('SeqComponentComposition')->create(
    {id_seq_component => $id_component1, id_seq_composition => $id_composition, size => 2});
  $schema->resultset('SeqComponentComposition')->create(
    {id_seq_component => $id_component2, id_seq_composition => $id_composition, size => 2});

  my $r = $ss_rs->search({})->next();
  my $composition;
  lives_ok {$composition = $r->composition()} 'composition object generated';
  is ($composition->freeze(),
    '{"components":[{"id_run":17448,"position":1,"tag_index":9},' .
                   '{"id_run":17448,"position":2,"tag_index":9}]}',
    'json representation');
  is ($r->rpt_key, '17448:1:9;17448:2:9', 'rpt key');
  ok ($r-> equals_byvalue({class_name => 'sequence_summary'}), 'class name comparison');
  ok ($r-> equals_byvalue({check_name => 'sequence summary'}), 'check name comparison');
  throws_ok {$r-> equals_byvalue({id_run => 17448})}
    qr/Not ready to deal with multi-component composition/,
    'other comparisons are not supported';


  my $values =  _get_data('17448_1#9.sequence_summary.json');
  $fk_row = $schema->resultset('SeqComposition')->create({digest => '12345678', size => 1});
  $id_composition = $fk_row->id_seq_composition;
  $schema->resultset('SeqComponentComposition')->create(
    {id_seq_component => $id_component1, id_seq_composition => $id_composition, size => 1});

  my $object = $ss_rs->new_result($values);
  isa_ok($object, 'npg_qc::Schema::Result::SequenceSummary');
  $object->id_seq_composition($id_composition);
  $r = $object->insert();

  lives_ok {$composition = $r->composition()} 'composition object generated';
  is ($composition->freeze(),
    '{"components":[{"id_run":17448,"position":1,"tag_index":9}]}',
    'json representation');
  is ($r->rpt_key, '17448:1:9', 'rpt key');
  ok ($r-> equals_byvalue({class_name => 'sequence_summary'}), 'class name comparison');
  ok ($r-> equals_byvalue({check_name => 'sequence summary'}), 'check name comparison');
  ok ($r-> equals_byvalue({id_run => 17448, position => 1}),
    'id_run and position name comparison');
  ok (!$r-> equals_byvalue({tag_index => undef}), 'tag_index comparison');
  ok (!$r-> equals_byvalue({tag_index => 1}), 'tag_index comparison');
  ok ($r-> equals_byvalue({tag_index => 9}), 'tag_index comparison');
};

1;


