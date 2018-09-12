#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ( -d "$Bin/../lib/perl5" ? "$Bin/../lib/perl5" : "$Bin/../lib" );
use Readonly;
use POSIX qw(strftime);
use Math::Round qw(round);

use npg_qc::Schema;

Readonly::Scalar my $UPDATE_AFTER   => 10_000;
Readonly::Scalar my $THOUSAND       => 1_000;
Readonly::Array  my @SECTIONS       => qw/forward reverse/;

my $schema  = npg_qc::Schema->connect();
my $rs_target = $schema->resultset('Fastqcheck');
my $rs_source = $schema->resultset('QXYield')
                ->search({'id_run'   => {'!=', undef}},
                         {'columns' => [qw/id_run
                                           position
                                           tag_index
                                           yield1_q30
                                           yield1_q40
                                           yield2_q30
                                           yield2_q40/]});

my $count  = $rs_source->count;
my $id_max = $rs_source->get_column('id_qx_yield')->max;
my $num_pages = int($id_max / $UPDATE_AFTER);
if ($id_max % $UPDATE_AFTER != 0) {
  $num_pages++;
}
warn "$count RECORDS WILL BE SPLIT INTO $num_pages PAGES\n";

my $current_page = 0;
my $num_checked  = 0;
my $num_failed   = 0;

while ($current_page < $num_pages) {

  my $time = strftime "%b %e %H:%M:%S", gmtime;
  warn sprintf '%s == PAGE NUMBER %i == %i RECORDS OK == %i RECORDS FAILED%s',
               $time, $current_page, $num_checked, $num_failed, "\n";

  my $id_min  = $current_page * $UPDATE_AFTER + 1;
  my $id_max  = $id_min + $UPDATE_AFTER;
  my $rs_page = $rs_source->search({'id_qx_yield' => {-between => [$id_min, $id_max]}});

  while (my $result = $rs_page->next()) {

    my $ref = {'id_run'   => $result->id_run,
               'position' => $result->position,
               'split'    => 'none'};
    $ref->{'tag_index'} = defined $result->tag_index ? $result->tag_index : -1;

    foreach my $read (@SECTIONS) {
      my $desc = sprintf '%i_%i#%i.%s', $ref->{'id_run'}, 
                                        $ref->{'position'},
                                        $ref->{'tag_index'},
                                        $read;
      $ref->{'section'} = $read;
      my $fqck_row = $rs_target->find($ref);
      my $index = $read eq 'forward' ? 1 : 2;
      my $name = 'yield' . $index;
      my $q30_name = 'yield' . $index . '_q30';
      my $q40_name = 'yield' . $index . '_q40';

      if (!$fqck_row) {
        if (defined $result->$q30_name || defined $result->$q40_name) {
          warn "$desc -- Records where there should not be any\n";
          $num_failed++;
        }
      } else {
        foreach my $q (qw/thirty forty/) {
          my $qx_name = $q eq 'thirty' ? $q30_name : $q40_name;
          if (defined $fqck_row->$q) {
            if (!defined $result->$qx_name) {
              warn "$desc -- No record where there should be one\n";
              $num_failed++;
            } else {
              if (round ($fqck_row->$q / $THOUSAND) != $result->$qx_name) {
                warn "$desc -- Wrong number\n";
                $num_failed++;
              }
            }
          } else {
            if (defined $result->$qx_name) {
              warn "$desc -- Records where there should not be any ==\n";
              $num_failed++;
            }
          }
        }
      }
      $num_checked++;
    }
  }

  $current_page++;
}

warn "\n$num_checked RECORDES OK, $num_failed FAILED\n";

exit 0;
