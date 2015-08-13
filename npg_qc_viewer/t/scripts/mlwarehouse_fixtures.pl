use strict;
use warnings;
use WTSI::DNAP::Warehouse::Schema;
use t::util;
use YAML qw(LoadFile DumpFile);
use Cwd;
use Readonly;
use File::Spec::Functions qw(catfile);

Readonly::Scalar our $FEATURE_EXTENSION => q[.yml];
my $util = t::util->new();
my $path = q[t/data/fixtures/mlwarehouse];
my $real = WTSI::DNAP::Warehouse::Schema->connect();
my $tname;
my $rs;

sub rs_list2fixture_filtered {
  my ($tname, $rs_list, $path, $remove, $mask) = @_;

  if (!$path) {
    $path = getcwd();
  }
  my @rows = ();
  foreach my $rs (@{$rs_list}) {
    while (my $r = $rs->next) {
      my $all_columns = {$r->get_columns};
      if (defined $remove) {
        foreach my $to_remove (@{$remove}) {
          delete $all_columns->{$to_remove};
        }
      }
      if (defined $mask) {
        foreach my $to_mask (keys %{$mask}) {
          $all_columns->{$to_mask} = $mask->{$to_mask};
        }
      }
      push @rows, $all_columns;
    }
  }
  DumpFile(catfile($path,$tname).$FEATURE_EXTENSION, \@rows);
  return;
}

{
  ############   iseq_product_metrics  #######################
  my $run_ids = [1272, 
                 3323,
                 3055, #For sample  
                 3500, 
                 3965, 
                 4025, 
                 4950];
  $tname = q[IseqProductMetric];
  $rs = $real->resultset($tname)->search(
              { 'id_run' => $run_ids},
  );
  $util->rs_list2fixture(q[300-].$tname, [$rs], $path);

  ############   iseq_flowcell  #######################
  $tname = q[IseqFlowcell];
  $rs = $real->resultset($tname)->search(
              { 'iseq_product_metrics.id_run' => $run_ids},
              {  join                        => ['iseq_product_metrics'],
              }
  );
  $util->rs_list2fixture(q[400-].$tname, [$rs], $path);
  
  ############   iseq_run_lane_metrics  #######################
  $tname = q[IseqRunLaneMetric];
  $rs = $real->resultset($tname)->search(
              { 'iseq_product_metrics.id_run' => $run_ids},
              {  join                        => ['iseq_product_metrics'],
                 distinct => 1, # Otherwise there are duplicate rows.
              },
  );
  $util->rs_list2fixture(q[400-].$tname, [$rs], $path);
  
  ###########    sample    ####################################
  $tname = q[Sample];
  $rs = $real->resultset($tname)->search(
              { 'iseq_product_metrics.id_run' => $run_ids },
              { join => {'iseq_flowcells' => 'iseq_product_metrics' }, 
                distinct => 1,
              },
  );
  my $remove = [qw/ father
                    mother
                    replicate
                    ethnicity
                    gender
                    cohort
                    country_of_origin
                    geographical_region
                    supplier_name /];
  my $mask = { name        => q[random_sample_name], };
  rs_list2fixture_filtered(q[500-].$tname, [$rs], $path, $remove, $mask);
  
  ###########    study     ####################################
  $tname = q[Study];
  $rs = $real->resultset($tname)->search(
              { 'iseq_product_metrics.id_run' => $run_ids },
              { join => {'iseq_flowcells' => 'iseq_product_metrics' },
                distinct => 1,
              },
  );
  $remove = [qw/ ethically_approved
                    faculty_sponsor
                    abstract
                    description /];
  $mask = { name        => q[random_study_name], 
            study_title => q[random_study_title] };
  rs_list2fixture_filtered(q[500-].$tname, [$rs], $path, $remove, $mask);
}

1;
