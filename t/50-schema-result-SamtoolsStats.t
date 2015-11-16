use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;
use File::Temp qw/ tempdir /;
use Archive::Extract;
use Perl6::Slurp;
use JSON;
use npg_testing::db;

use_ok('npg_qc::Schema::Result::SamtoolsStats');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

my $tempdir = tempdir( CLEANUP => 1);
my $archive = '17448_1_9';
my $ae = Archive::Extract->new(archive => "t/data/autoqc/bam_flagstats/${archive}.tar.gz");
$ae->extract(to => $tempdir) or die $ae->error;
$archive = join q[/], $tempdir, $archive, 'qc', 'all_json';

my $ss_rs = $schema->resultset('SamtoolsStats');
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

subtest 'load results for the same composition' => sub {
  plan tests => 10;

  my $values =  _get_data('17448_1#9_F0xB00.samtools_stats.json');
  my $fk_row = $schema->resultset('SeqComposition')->create({digest => '45678', size => 2});

  my $object = $ss_rs->new_result($values);
  isa_ok($object, 'npg_qc::Schema::Result::SamtoolsStats');
  throws_ok {$object->insert()}
    qr/NOT NULL constraint failed: samtools_stats.id_seq_composition/,
    'foreign key referencing the composition table absent - error';

  $object->id_seq_composition($fk_row->id_seq_composition);
  lives_ok { $object->insert() } 'insert with fk is ok';
  my $rs = $ss_rs->search({});
  is ($rs->count, 1, q[one row created in the table]);
  my $row = $rs->next;
  is ($row->stats, $values->{'stats'}, 'content of the stats file retrieved correctly');
  is ($row->filter, 'F0xB00', 'filter value is correct');

  $values =  _get_data('17448_1#9_F0x900.samtools_stats.json');
  $values->{'id_seq_composition'} = $fk_row->id_seq_composition;
  $ss_rs->new_result($values)->insert();
  is ($ss_rs->search({})->count, 2, q[two rows created in the table for the same composition]);

  $values =  _get_data('17448_1#9_phix_F0x900.samtools_stats.json');
  $values->{'id_seq_composition'} = $fk_row->id_seq_composition;
  throws_ok { $ss_rs->create($values) }
    qr/UNIQUE constraint failed: samtools_stats\.id_seq_composition, samtools_stats\.filter/,
    'cannot create a record with the same set of unique keys';
  lives_ok { $ss_rs->update_or_create($values) }
    'can update existing value';
  is ($ss_rs->search({})->count, 2, 'still two rows');
};

1;


