package npg_qc_viewer::Controller::Checks;

use Moose;
use namespace::autoclean;
use Moose::Meta::Class;
use URI::URL;
use Carp;
use List::MoreUtils qw/ none /;

use npg_qc::autoqc::qc_store::options qw/$ALL $LANES $PLEXES/;
use npg_qc::autoqc::role::rpt_key;
use npg_qc::autoqc::results::collection;
use npg_qc_viewer::TransferObjects::ProductMetrics4RunTO;

BEGIN { extends 'Catalyst::Controller' }

our $VERSION   = '0';
## no critic (Documentation::RequirePodAtEnd Subroutines::ProhibitBuiltinHomonyms ProhibitLongChainsOfMethodCalls )

Readonly::Scalar our $DEFAULT_RESULTS_RETRIEVE_OPTION => q[lanes];
Readonly::Hash   our %RESULTS_RETRIEVE_OPTIONS => ('all'    => $ALL,
                                                   'lane'   => $LANES,
                                                   'lanes'  => $LANES,
                                                   'plex'   => $PLEXES,
                                                   'plexes' => $PLEXES,
                                                  );
=head1 NAME

npg_qc_viewer::Controller::Checks

=head1 SYNOPSIS

=head1 DESCRIPTION

NPG SeqQC Controller for URLs of pages displaying autoqc results

=head1 SUBROUTINES/METHODS

=cut

sub _base_url_no_port {
  my $base_url = shift;

  if (!$base_url) {
    croak 'Need base url';
  }
  my $url = URI::URL->new($base_url);
  my $port = $url->port;
  if ($port) {
    $url =~ s/:${port}//xms; #remove port number and preceeding :
  }
  $url =~ s{/\Z}{}xms; # trim the last slash
  return $url;
}

sub _get_title {
  my $title = shift;
  my $full_title =  qq[NPG SeqQC v$VERSION];
  if ($title) {
    $full_title .= ': ' . $title;
  }
  return $full_title;
}

sub _test_positive_int {
  my ($self, $c, $input) = @_;
  if ($input !~ /^\d+$/smx || $input == 0) {
    $c->stash->{error_message} =
       qq[The last URL component must be a positive integer. You entered $input];
    $c->detach(q[Root], q[error_page]);
  }
  return;
}

sub _show_option {
  my ($self, $c, $default) = @_;
  my $what;
  if (exists $c->request->query_parameters->{'show'}) {
    $what = $c->request->query_parameters->{'show'};
  }
  if (!$what || !exists $RESULTS_RETRIEVE_OPTIONS{$what}) {
    $what = $default ? $default : $DEFAULT_RESULTS_RETRIEVE_OPTION;
  }
  return $what;
}

sub _data2stash {
  my ($self, $c, $collection) = @_;

  my $rl_map   = $collection->run_lane_collections;
  my $has_plexes = npg_qc::autoqc::role::rpt_key->has_plexes([keys %{$rl_map}]);
  $c->stash->{'rl_map'}     = $rl_map;
  $c->stash->{'has_plexes'}   = $has_plexes;
  $c->stash->{'collection_all'} = $collection;
  return;
}

sub _filter_run_lane_collection_with_keys {
  my ($self, $collection, $keys) = @_;

  my $temp_collection = npg_qc::autoqc::results::collection->new();
  my $temp_run_lanes = $collection->run_lane_collections;
  foreach my $key ( @{$keys} ) {
    if ( $temp_run_lanes->{$key} ) {
      $temp_collection->add($temp_run_lanes->{$key}->results);
    }
  }

  return $temp_collection;
}

sub _as_query_conditions {
  my ($self, $obj) = @_;
  my $conditions = {};

  $conditions->{'id_run'}   = $obj->id_run;
  $conditions->{'position'} = $obj->position;
  if ( $obj->tag_index ) {
    $conditions->{'tag_index'} = $obj->tag_index;
  }

  return $conditions;
}

sub _display_libs {
  my ($self, $c, $rs, $what) = @_;

  if ($rs) {
    $c->stash->{'db_lookup'} = 1;

    my $run_lane_map = {};
    my $rpt_keys = [];
    while (my $row = $rs->next) {
      my $id_run   = $row->id_run;
      my $position = $row->position;
      my $where = $self->_as_query_conditions($row);

      if ( $what == $LANES ) {
        #Only process run+lane once disregarding how many plexes matched the pool
        my $run_lane_key = $row->lane_rpt_key_from_key($row->rpt_key);
        if ( none { $_ eq $run_lane_key } @{ $rpt_keys } ) {
          $self->_run_lanes_from_dwh($c, $where, $what);
          push @{ $rpt_keys }, $run_lane_key;
        }
      } else {
        push @{$rpt_keys}, $row->rpt_key;
        $self->_run_lanes_from_dwh($c, $where, $what);
      }

      if (exists $run_lane_map->{$id_run}) {
        if ( none { $_ eq $position } @{ $run_lane_map->{$id_run} } ) {
          push @{$run_lane_map->{$id_run}}, $position;
        }
      } else {
        $run_lane_map->{$id_run} = [$position];
      }
    }

    my $collection = $c->model('Check')->load_lanes(
      $run_lane_map, $c->stash->{'db_lookup'}, $what, $c->model('NpgDB')->schema);
    $collection = $self->_filter_run_lane_collection_with_keys($collection, $rpt_keys);

    $self->_data2stash($c, $collection);
  }

  return;
}

sub _display_run_lanes {
  my ($self, $c, $params) = @_;

  my $id_runs;
  my $lanes = [];

  if ($params && exists $params->{'run'}) {
    $id_runs = $params->{'run'};
    if ($params->{'lane'}) {
      $lanes = $params->{'lane'};
    }
  } else {
    $id_runs = $c->request->query_parameters->{'run'};
    if (!ref $id_runs) {
      $id_runs = [$id_runs];
    }
  }

  if (exists $c->request->query_parameters->{'lane'}) {
    $lanes = $c->request->query_parameters->{'lane'};
    if (!ref $lanes) {
      $lanes = [$lanes];
    }
  }

  if (exists $c->request->query_parameters->{'db_lookup'}) {
    $c->stash->{'db_lookup'} = $c->request->query_parameters->{'db_lookup'};
  }

  my $run_lanes = {};
  foreach my $id_run (@{$id_runs}) {
    $run_lanes->{$id_run} = $lanes;
  }

  my $what = $self->_show_option($c);
  my $retrieve_option = $RESULTS_RETRIEVE_OPTIONS{$what};
  my $collection = $c->model('Check')->load_lanes(
    $run_lanes, $c->stash->{'db_lookup'}, $retrieve_option, $c->model('NpgDB')->schema);

  my $where = { 'id_run' => $id_runs };
  if (scalar @{$lanes}) { $where->{'position'} = $lanes };

  $self->_run_lanes_from_dwh($c, $where, $retrieve_option);

  $self->_data2stash($c, $collection);

  if (!$c->stash->{'title'} ) {
    my $title = q[Results ];
    if (!$c->stash->{'db_lookup'}) {
      $title .= q[(staging) ];
    }
    if (@{$id_runs}) {
      $title .= qq[($what) for runs ] . (join q[ ], @{$id_runs});
    }
    if (@{$lanes}) {
      $title .= q[ lanes ] . (join q[ ], @{$lanes});
    }
    $c->stash->{'title'} = _get_title($title);
  }

  if ($retrieve_option ne $ALL) {
    $c->stash->{'show_total'} = 1;
  }

  return;
}

sub _run_lanes_from_dwh {
  my ($self, $c, $where, $retrieve_option) = @_;

  my $row_data = $c->stash->{'row_data'} || {};
  my $rs = $c->model('MLWarehouseDB')->search_product_metrics($where);

  while (my $product_metric = $rs->next) {
    if ($retrieve_option == $LANES || $retrieve_option == $ALL) {
      if ( !defined $product_metric->tag_index ||
           ( $product_metric->iseq_flowcell
             && $product_metric->iseq_flowcell->entity_type ne 'library_indexed_spike' )) {
        #Using first tax index available as representative for the lane.

        my $key = $product_metric->rpt_key;
        if ( $product_metric->tag_index ) {
          $key = $product_metric->lane_rpt_key_from_key($key);
        }
        if ( !exists $row_data->{$key} ) {
          $row_data->{$key} =
            npg_qc_viewer::TransferObjects::ProductMetrics4RunTO->new(
              $self->_build_hash($product_metric));
        }
      }
    }

    if ($retrieve_option == $ALL || $retrieve_option == $PLEXES) {
      if (defined $product_metric->tag_index) {
        my $key = $product_metric->rpt_key;
        if ( !defined $row_data->{$key} ) {
          my $values = $self->_build_hash($product_metric);
          delete $values->{'manual_qc'};
          $row_data->{$key} =
            npg_qc_viewer::TransferObjects::ProductMetrics4RunTO->new($values);
        }
      }
    }
  }

  $c->stash->{'row_data'} = $row_data;

  return;
}

sub _build_hash {
  my ($self, $product_metric) = @_;

  my $values = {};
  $values->{'id_run'}       = $product_metric->id_run;
  $values->{'position'}     = $product_metric->position;
  $values->{'tag_index'}    = $product_metric->tag_index;
  $values->{'tag_sequence'} = $product_metric->tag_sequence4deplexing;

  $values->{'num_cycles'}   = $product_metric->iseq_run_lane_metric->cycles;
  $values->{'time_comp'}    = $product_metric->iseq_run_lane_metric->run_complete;

  if ( defined $product_metric->iseq_flowcell ) {
    my $flowcell = $product_metric->iseq_flowcell;
    $values->{'id_library_lims'}   = $flowcell->id_library_lims;
    $values->{'legacy_library_id'} = $flowcell->legacy_library_id;
    $values->{'id_pool_lims'}      = $flowcell->id_pool_lims;
    $values->{'rnd'}               = $flowcell->is_r_and_d;
    $values->{'manual_qc'}         = $flowcell->manual_qc;
    $values->{'is_gclp'}           = $flowcell->from_gclp;
    $values->{'entity_id_lims'}    = $flowcell->entity_id_lims;
    $values->{'study_name'}        = $flowcell->study_name;
    $values->{'id_sample_lims'}    = $flowcell->sample_id;
    $values->{'sample_name'}       = $flowcell->sample_name;
  }

  return $values;
}

=head2 base

Action for the base controller path

=cut
sub base :Chained('/') :PathPart('checks') :CaptureArgs(0)
{
  my ($self, $c) = @_;
  $c->stash->{'util'}       = Moose::Meta::Class->create_anon_class(
            roles => ['npg_qc::autoqc::role::rpt_key'])->new_object();
  $c->stash->{'rl_map'}       = {};
  $c->stash->{'db_lookup'}    = 1;
  $c->stash->{'env_dev'}      = $ENV{dev};
  $c->stash->{'run_view'}     = 0;
  $c->stash->{'run_from_staging'} = 0;
  $c->stash->{'base_url'}     = _base_url_no_port($c->request->base);
  $c->stash->{'template'}     = q[ui_lanes/library_lanes.tt2];
  return;
}

=head2 index

index page

=cut
sub index :Path :Args(0) {
  my ( $self, $c ) = @_;
  $c->stash->{'title'} = _get_title();
  $c->stash->{'template'} = q[about.tt2];
  return;
}

=head2 about

qc checks info page

=cut
sub about :Path('about') :Args(0) {
  my ( $self, $c ) = @_;
  $c->stash->{'title'} = _get_title(q[about QC checks]);
  $c->stash->{'template'} = q[about_qc_checks.tt2];
  return;
}

=head2 list_runs

More complex URLs for runs

=cut
sub list_runs :Chained('base') :PathPart('runs') :Args(0) {
  my ($self, $c) = @_;

  if (defined $c->request->query_parameters->{run}) {
    $c->stash->{'db_lookup'} = 1;
    $self->_display_run_lanes($c);
  } else {
    $c->stash->{error_message} = q[This is an invalid URL];
    $c->detach(q[Root], q[error_page]);
  }
  return;
}


=head2 checks_in_run

Fetches the checks collection for a run and passes it to the relevant
template through the stash

=cut
sub checks_in_run :Chained('base') :PathPart('runs') :Args(1) {
  my ($self, $c, $id_run) = @_;
  $self->_test_positive_int($c, $id_run);
  #if config is needed, it's available through $c->config
  $c->stash->{'title'}   = _get_title(qq[Results for run $id_run]);
  $c->stash->{'run_view'}  = 1;
  $c->stash->{'id_run'}  = $id_run;
  $self->_display_run_lanes($c, {run => [$id_run],} );
  return;
}


=head2 runs_from_staging

Fetches the checks collection for a run from the staging area
and passes it to the relevant template through the stash

=cut
sub runs_from_staging :Chained('base') :PathPart('runs-from-staging') :Args(0) {
  my ($self, $c) = @_;

  if (exists $c->request->query_parameters->{run}) {
    $c->stash->{'db_lookup'} = 0;
    $self->_display_run_lanes($c);
  } else {
    $c->stash->{error_message} =
       q[Run to load is not given. Append ?run=some_run to URL];
    $c->detach(q[Root], q[error_page]);
  }
  return;
}


=head2 checks_in_run_from_staging

Fetches the checks collection for a run from the staging area
and passes it to the relevant template through the stash

=cut
sub checks_in_run_from_staging :Chained('base') :PathPart('runs-from-staging') :Args(1) {
  my ($self, $c, $id_run) = @_;

  $self->_test_positive_int($c, $id_run);
  $c->stash->{'db_lookup'}    = 0;
  $c->stash->{'title'}      = _get_title(qq[Staging results for run $id_run]);
  $c->stash->{'run_from_staging'} = 1;
  $c->stash->{'run_view'}     = 1;
  $c->stash->{'id_run'}       = $id_run;
  $self->_display_run_lanes($c, {run => [$id_run],} );
  return;
}

=head2 checks_from_path

Fetches the checks collection from a given path

=cut
sub checks_from_path :Chained('base') :PathPart('path') :Args(0) {
  my ($self, $c) = @_;

  if ($c->request->query_parameters->{'path'}) {
    my $path_arg = $c->request->query_parameters->{'path'};
    my @path = ref $path_arg ? @{$path_arg} : ($path_arg);
    $c->stash->{'title'} = _get_title(q[Results from ] . join q[,], @path);
    my $collection = $c->model('Check')->load_from_path(@path);
    $self->_data2stash($c, $collection);
    $c->stash->{'db_lookup'} = 0;
    $c->stash->{'path_list'} = [@path];
  } else {
    $c->stash->{error_message} =
      q[Path to load results from not given. Append ?path=some_abs_path to URL];
    $c->detach(q[Root], q[error_page]);
  }
  return;
}

=head2 libraries

Library page.

=cut
sub libraries :Chained('base') :PathPart('libraries') :Args(0) {
  my ( $self, $c) = @_;

  if (defined $c->request->query_parameters->{'id'}) {
    my $id_library_lims = $c->request->query_parameters->{'id'};
    if (!ref $id_library_lims) {
      $id_library_lims = [$id_library_lims];
    }
    $c->stash->{'title'} = _get_title(q[Libraries: ] . join q[, ], map {q['].$_.q[']} @{$id_library_lims});
    my $rs = $c->model('MLWarehouseDB')->search_product_by_id_library_lims($id_library_lims);
    $c->stash->{'sample_link'} = 1;
    $self->_display_libs($c, $rs, $ALL);
  } else {
    $c->stash->{error_message} = q[This is an invalid URL];
    $c->detach(q[Root], q[error_page]);
  }
  return;
}

=head2 pools

Pools page - retained in order not to change dispatch type for a pool

=cut
sub pools :Chained('base') :PathPart('pools') :Args(0) {
  my ($self, $c) = @_;
  $c->stash->{error_message} = q[This is an invalid URL];
  $c->detach(q[Root], q[error_page]);
  return;
}

=head2 pool

Pool page.

=cut
sub pool :Chained('base') :PathPart('pools') :Args(1) {
  my ( $self, $c, $id_pool_lims) = @_;

  $c->stash->{'title'} = _get_title(qq[Pool $id_pool_lims]);
  my $rs = $c->model('MLWarehouseDB')->search_product_by_id_pool_lims($id_pool_lims);
  $c->stash->{'sample_link'} = 0;
  $c->stash->{'show_total'}  = 1;
  $self->_display_libs($c, $rs, $LANES);
  return;
}

=head2 samples

Samples page - retained in order not to change dispatch type for a sample

=cut
sub samples :Chained('base') :PathPart('samples') :Args(0) {
  my ($self, $c) = @_;
  $c->stash->{error_message} = q[This is an invalid URL];
  $c->detach(q[Root], q[error_page]);
  return;
}

=head2 sample

Sample page

=cut
sub sample :Chained('base') :PathPart('samples') :Args(1) {
  my ( $self, $c, $id_sample_lims) = @_;

  my $sample = $c->model('MLWarehouseDB')->search_sample_by_sample_id($id_sample_lims)->next;
  if (!$sample) {
    $c->stash->{error_message} = qq[Unknown sample id $id_sample_lims];
    $c->detach(q[Root], q[error_page]);
    return;
  }

  my $sample_name = $sample->name;
  my $rs = $c->model('MLWarehouseDB')->search_product_by_sample_id($id_sample_lims);
  $c->stash->{'sample_link'} = 0;
  $c->stash->{'show_total'}  = 1;
  $self->_display_libs($c, $rs, $ALL);
  $c->stash->{'title'} = _get_title(qq[Sample '$sample_name']);
  return;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Moose::Meta::Class

=item URI::URL

=item Carp

=item List::MoreUtils

=item npg_qc::autoqc::qc_store::options

=item npg_qc::autoqc::role::rpt_key

=item Catalyst::Controller

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 Genome Research Ltd

This file is part of NPG software.

NPG is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
