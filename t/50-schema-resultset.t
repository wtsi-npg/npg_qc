use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;
use Moose::Meta::Class;
use npg_tracking::glossary::composition::component::illumina;
use npg_tracking::glossary::composition::factory;

use_ok 'npg_qc::Schema';

my $schema_package = q[npg_qc::Schema];
my $schema;
lives_ok{ $schema = Moose::Meta::Class->create_anon_class(
            roles => [qw/npg_testing::db/])->new_object()
            ->create_test_db($schema_package) } 'test db created';
isa_ok($schema, $schema_package);

subtest q[results with id_run and position only in the table] => sub {
  plan tests => 2;

  $schema->resultset('SpatialFilter')->create({id_run => 8926, position => 2});
  is ($schema->resultset('SpatialFilter')->search({
    id_run => 8926, position => 2})->count(), 1, 'one result');
  throws_ok {$schema->resultset('SpatialFilter')->search({
    id_run => 8926, position => 2, tag_index => undef})->count()}
    qr/no such column: tag_index/,
    'error with tag_index as a part of the query';
};

subtest q[results with id_run, position and tag_index in the table] => sub {
  plan tests => 15;

  my $is_rs = $schema->resultset('InsertSize');
  $is_rs->create({id_run => 3500, position => 1});
  my $rs = $is_rs->search_autoqc({id_run => 3500, position => 1});
  is ($rs->count, 1, 'one result retrieved');
  is ($rs->next->tag_index, undef, 'lane-level result');
  $rs = $is_rs->search_autoqc({id_run => 3500, position => 2});
  is ($rs->count, 0, 'no results retrieved');
  
  $rs = $is_rs->search_autoqc({id_run => 3500, position => 1, tag_index => undef});
  is ($rs->count, 1, 'one result retrieved');
  is ($rs->next->tag_index, undef, 'lane-level result');

  $rs = $is_rs->search_autoqc({id_run => 3500, position => 1, tag_index => 0});
  is ($rs->count, 0, 'no results retrieved');

  foreach my $i ((0 .. 10)) {
    foreach my $p ((1 .. 2)) {
      foreach my $r ((3500, 4000, 5000)) {
        $is_rs->create({id_run => $r, position => $p, tag_index => $i});
      }
    }
  }
  
  $rs = $is_rs->search_autoqc({id_run => 3500, position => 1});
  is ($rs->count, 12, '12 results retrieved');
  $rs = $is_rs->search_autoqc({id_run => 3500, position => 2});
  is ($rs->count, 11, '11 results retrieved');
  $rs = $is_rs->search_autoqc({id_run => 3500, position => 1, tag_index => undef});
  is ($rs->count, 1, '1 result retrieved');
  $rs = $is_rs->search_autoqc({id_run => 3500, position => 2, tag_index => undef});
  is ($rs->count, 0, 'no results retrieved');
  $rs = $is_rs->search_autoqc({id_run => 3500, position => 1, tag_index => 0});
  is ($rs->count, 1, 'one result retrieved');
  $rs = $is_rs->search_autoqc({id_run => 3500, position => [1,2], tag_index => 0});
  is ($rs->count, 2, 'two results retrieved');
  $rs = $is_rs->search_autoqc({id_run => 3500, position => [1,2], tag_index => [1,3,5,7]});
  is ($rs->count, 8, '8 results retrieved');
  $rs = $is_rs->search_autoqc({tag_index => [1,3]});
  is ($rs->count, 12, '12 results retrieved');
  $rs = $is_rs->search_autoqc({id_run => [3500,5000], position => [1,2], tag_index => undef});
  is ($rs->count, 1, '1 result retrieved');
};

subtest q[results with id_run, position, tag_index and subset in the table] => sub {
  plan tests => 9;

  my $fs_rs = $schema->resultset('BamFlagstats');
  foreach my $i ((0 .. 10)) {
    foreach my $p ((1 .. 2)) {
      foreach my $r ((3500, 4000, 5000)) {
        foreach my $s (qw/target human phix/) {
          my $hs = $s eq 'target' ? 'all' : $s;
          $fs_rs->create(
            {id_run => $r, position => $p, tag_index => $i, subset => $s, human_split => $hs});
        }
      }
    }
  }

  my $rs = $fs_rs->search_autoqc({id_run => 3500, position => 1});
  is ($rs->count, 33, '33 results retrieved');
  $rs = $fs_rs->search_autoqc({id_run => 3500, position => 1, tag_index => undef});
  is ($rs->count, 0, 'no results retrieved');
  $rs = $fs_rs->search_autoqc({id_run => 3500, position => 1, tag_index => 0});
  is ($rs->count, 3, '3 results retrieved');
  $rs = $fs_rs->search_autoqc({id_run => 3500, position => [1,2], tag_index => 0});
  is ($rs->count, 6, '6 results retrieved');
  $rs = $fs_rs->search_autoqc({id_run => 4000, position => [1,2], tag_index => 3, human_split => undef});
  is ($rs->count, 2, '2 results retrieved');
  $rs = $fs_rs->search_autoqc({id_run => 5000, position => 1, tag_index => 3, human_split => 'human'});
  is ($rs->count, 1, 'one result retrieved');
  $rs = $fs_rs->search_autoqc({id_run => 5000, position => 1, tag_index => 3, human_split => 'yhuman'});
  is ($rs->count, 0, 'no results retrieved');
  $rs = $fs_rs->search_autoqc({human_split => ['phix']});
  is ($rs->count, 66, '66 results retrieved');
  $rs = $fs_rs->search_autoqc({human_split => undef});
  is ($rs->count, 66, '66 results retrieved');
};

sub _seq_summary_data {
  my $id = shift;
  return {id_seq_composition => $id,
          sequence_format    => 'cram',
          header             => 'my header',
          seqchksum          => '123456789',
          seqchksum_sha512   => '1122334455667788',
          md5                => 'gjsgfjfhgjs',
         };
}

sub _samtools_data {
  my ($id, $filter) = @_;
  return {id_seq_composition => $id,
          filter             => $filter,
          stats              => 'ffhgfhgfh',
         };
}

subtest q[results linked to composition] => sub {
  plan tests => 23;

  my $component_rs   = $schema->resultset('SeqComponent');
  my $composition_rs = $schema->resultset('SeqComposition');
  my $com_com_rs     = $schema->resultset('SeqComponentComposition');
  my $samtools_rs    = $schema->resultset('SamtoolsStats');
  my $summary_rs     = $schema->resultset('SequenceSummary');

  my $stash = {};

  foreach my $i ((0 .. 10)) {
    foreach my $p ((1 .. 2)) {
      foreach my $r ((3500, 4000, 5000)) {
        foreach my $s (('human', undef, 'phix')) {
          my $component_h = {id_run => $r, position => $p, tag_index => $i, subset => $s};
          my $component =
            npg_tracking::glossary::composition::component::illumina->new($component_h);
          my $f = npg_tracking::glossary::composition::factory->new();
          $f->add_component($component);
          my $composition = $f->create_composition();
          $component_h->{'digest'} = $component->digest;
          my $component_row = $component_rs->create($component_h);
          if ($r == 4000 && $p == 1 && !defined $s) {
            $stash->{$i}->{'component'} = $component;
            $stash->{$i}->{'row'} = $component_row;
          }
          my $composition_row = $composition_rs->create(
            {size => 1, digest => $composition->digest});
          $com_com_rs->create({size => 1,
                               id_seq_component   => $component_row->id_seq_component,
                               id_seq_composition => $composition_row->id_seq_composition
                              });
      
          $summary_rs->create(_seq_summary_data($composition_row->id_seq_composition));
          $samtools_rs->create(_samtools_data($composition_row->id_seq_composition, 'f1'));
          $samtools_rs->create(_samtools_data($composition_row->id_seq_composition, 'f2'));

          if ($r == 5000 && $p == 1 && !defined $s) {
            $f = npg_tracking::glossary::composition::factory->new();
            $f->add_component($component);
            $f->add_component($stash->{$i}->{'component'});
            $composition = $f->create_composition();
            $composition_row = $composition_rs->create(
              {size => 1, digest => $composition->digest});
            $com_com_rs->create({size => 2,
                                 id_seq_component   => $component_row->id_seq_component,
                                 id_seq_composition => $composition_row->id_seq_composition
                                });
            $com_com_rs->create({size => 2,
                                 id_seq_component   => $stash->{$i}->{'row'}->id_seq_component,
                                 id_seq_composition => $composition_row->id_seq_composition
                                });
            $summary_rs->create(_seq_summary_data($composition_row->id_seq_composition));
            $samtools_rs->create(_samtools_data($composition_row->id_seq_composition, 'f1'));
            $samtools_rs->create(_samtools_data($composition_row->id_seq_composition, 'f2'));
          }
        }
      }
    }
  }

  my $rs = $summary_rs->search_autoqc({id_run => 3500, position => 1});
  is ($rs->count, 33, '33 results retrieved');
  $rs = $summary_rs->search_autoqc({id_run => 3500, position => 1}, 1);
  is ($rs->count, 33, '33 results retrieved');
  $rs = $summary_rs->search_autoqc({id_run => 3500, position => 1}, 2);
  is ($rs->count, 0, 'no results retrieved');

  $rs = $samtools_rs->search_autoqc({id_run => 3500, position => 1});
  is ($rs->count, 66, '66 results retrieved');
  $rs = $samtools_rs->search_autoqc({id_run => 3500, position => 1}, 1);
  is ($rs->count, 66, '66 results retrieved');
  $rs = $samtools_rs->search_autoqc({id_run => 3500, position => 1}, 2);
  is ($rs->count, 0, 'no results retrieved');

  $rs = $summary_rs->search_autoqc({id_run => 3500, position => 1, tag_index => undef});
  is ($rs->count, 0, 'no results retrieved');
  $rs = $summary_rs->search_autoqc({id_run => 3500, position => 1, tag_index => 0});
  is ($rs->count, 3, '3 results retrieved');
  $rs = $summary_rs->search_autoqc({id_run => 3500, position => [1,2], tag_index => 3});
  is ($rs->count, 6, '6 results retrieved');
  $rs = $summary_rs->search_autoqc({id_run => 3500, position => [1,2], tag_index => 3, subset => undef});
  is ($rs->count, 2, '2 results retrieved');
  $rs = $samtools_rs->search_autoqc({id_run => 3500, position => [1,2], tag_index => 3, subset => undef});
  is ($rs->count, 4, '4 results retrieved');
  $rs = $summary_rs->search_autoqc({id_run => 3500, position => 1, tag_index => 3, subset => 'human'});
  is ($rs->count, 1, 'one result retrieved');
  $rs = $summary_rs->search_autoqc({id_run => 3500, position => 1, tag_index => 3, subset => 'yhuman'});
  is ($rs->count, 0, 'no results retrieved');

  $rs = $summary_rs->search_autoqc({id_run => 3500, subset => ['phix']});
  is ($rs->count, 22, '22 results retrieved');
  $rs = $summary_rs->search_autoqc({id_run => 3500, subset => undef});
  is ($rs->count, 22, '22 results retrieved');

  $rs = $summary_rs->search_autoqc({id_run => 5000, subset => 'human'}, 1);
  is ($rs->count, 22, '22 results retrieved');
  $rs = $summary_rs->search_autoqc({id_run => 5000, subset => 'human'}, 2);
  is ($rs->count, 0, 'no results retrieved');
  $rs = $summary_rs->search_autoqc({id_run => 5000, subset => undef}, 1);
  is ($rs->count, 22, '22 results retrieved');
  $rs = $summary_rs->search_autoqc({id_run => 5000, subset => undef}, 2);
  is ($rs->count, 11, '11 results retrieved');
  $rs = $summary_rs->search_autoqc({id_run => 5000, subset => undef});
  is ($rs->count, 33, '33 results retrieved');
  $rs = $samtools_rs->search_autoqc({id_run => 5000, subset => undef}, 1);
  is ($rs->count, 44, '44 results retrieved');
  $rs = $samtools_rs->search_autoqc({id_run => 5000, subset => undef}, 2);
  is ($rs->count, 22, '22 results retrieved');
  $rs = $samtools_rs->search_autoqc({id_run => 5000, subset => undef});
  is ($rs->count, 66, '44 results retrieved');
};

1;
