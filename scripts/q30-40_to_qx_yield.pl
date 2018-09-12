#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ( -d "$Bin/../lib/perl5" ? "$Bin/../lib/perl5" : "$Bin/../lib" );
use Readonly;
use POSIX qw(strftime);
use Math::Round qw(round);

use npg_qc::Schema;
use npg_tracking::glossary::composition::factory;
use npg_tracking::glossary::composition::component::illumina;

Readonly::Scalar my $UPDATE_AFTER   => 10_000;
Readonly::Scalar my $THOUSAND       => 1_000;
Readonly::Scalar my $FK_COLUMN_NAME => 'id_seq_composition';

my $schema  = npg_qc::Schema->connect();
my $rs_target = $schema->resultset('QXYield');
my $rs_source = $schema->resultset('Fastqcheck')
                ->search({'split'   => 'none',
                          'section' => [qw/forward reverse/]},
                         {'columns' => [qw/id_fastqcheck
                                           id_run
                                           position
                                           tag_index
                                           section
                                           thirty
                                           forty/]});

my $count  = $rs_source->count;
my $id_max = $rs_source->get_column('id_fastqcheck')->max;
my $num_pages = int($id_max / $UPDATE_AFTER);
if ($id_max % $UPDATE_AFTER != 0) {
  $num_pages++;
}
warn "$count RECORDS TO COPY WILL BE SPLIT INTO $num_pages PAGES\n";

my $current_page = 0;
my $num_updated  = 0;
my $num_skipped  = 0;

while ($current_page < $num_pages) {

  my $time = strftime "%b %e %H:%M:%S", gmtime;
  warn sprintf '%s == PAGE NUMBER %i == %i COPIED RECORDS%s',
               $time, $current_page, $num_updated, "\n";

  my $id_min  = $current_page * $UPDATE_AFTER + 1;
  my $id_max  = $id_min + $UPDATE_AFTER;
  my $rs_page = $rs_source->search({'id_fastqcheck' => {-between => [$id_min, $id_max]}});

  while (my $result = $rs_page->next()) {

    my $ref = {'id_run' => $result->id_run, 'position' => $result->position};
    if (defined $result->tag_index) {
      $ref->{'tag_index'} = $result->tag_index;
    }
    my $factory = npg_tracking::glossary::composition::factory->new();
    my $component = npg_tracking::glossary::composition::component::illumina->new($ref);
    $factory->add_component($component);
    my $composition_obj = $factory->create_composition();

    my $composition_row = $rs_target->find_seq_composition($composition_obj);
    if ($composition_row) {
      my $up = {};
      for my $q (qw/thirty forty/) {
        if (defined $result->$q) {
          my $target_column_name = sprintf 'yield%i_q%i',
                                 $result->section eq 'forward' ? 1 : 2,
                                 $q               eq 'thirty'  ? 30 : 40;
          $up->{$target_column_name} = round($result->$q / $THOUSAND);
        }
      }
      if (keys %{$up}) {
        my $row = $rs_target->find(
          {$FK_COLUMN_NAME => $composition_row->$FK_COLUMN_NAME});
        if ($row) {
          $row->update($up);
          $num_updated++;
        } else {
          $num_skipped++;
          warn '=== No match in qx_yield for ' . $composition_obj->freeze .
            " , skipping, total skipped so far $num_skipped\n";
        }
      } else {
        $num_skipped++;
        warn sprintf 'NO DATA for %s %s read%s',
          $composition_obj->freeze, $result->section, "\n"; 
      }
    } else { # We are not interested in entities that do not exist anywhere else
      $num_skipped++;
      warn '=== No match for ' . $composition_obj->freeze .
        " , skipping, total skipped so far $num_skipped\n";
    }
  }

  $current_page++;
}

warn "\nNUMBER OF COPIED RECORDS $num_updated\n";

exit 0;
