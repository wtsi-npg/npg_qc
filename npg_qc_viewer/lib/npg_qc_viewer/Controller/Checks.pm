package npg_qc_viewer::Controller::Checks;

use Moose;
use namespace::autoclean;
use Moose::Meta::Class;
use Carp;
use English qw(-no_match_vars);

use npg_qc::autoqc::qc_store::options qw/$ALL $LANES $PLEXES/;
use npg_qc::autoqc::role::rpt_key;

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

=head1 VERSION

$Revision: 17383 $

=head1 SYNOPSIS

=head1 DESCRIPTION

NPG SeqQC Controller for URLs of pages displaying autoqc results

=head1 SUBROUTINES/METHODS

=cut

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

sub _wh_rows2run_lane_pairs {
    my ($self, $c) = @_;

    my $map = {};
    foreach my $rs_name (qw/rs plex_rs/) {
        if (!exists $c->stash->{$rs_name}) { next; }
        my $rset = $c->stash->{$rs_name};
        while (my $row = $rset->next) {
            my $id_run = $row->id_run;
            my $position = $row->position;
            if (exists $map->{$id_run}) {
                ## no critic (ProhibitBooleanGrep)
                if (!grep {/$position/smx} @{$map->{$id_run}}) {
                    push  @{$map->{$id_run}}, $position;
	              }
            ## use critic
	          } else {
                $map->{$id_run} = [$position];
	          }
	      }
        $rset->reset;
    }
    return $map;
}

sub _rl_map_append {
    my ($self, $c, $rl_map) = @_;

    my $rsets = {rs => 'NpgInformation', plex_rs => 'NpgPlexInformation',};
    my $wh_rl_map = {};
    foreach my $rs_name (keys %{$rsets}) {
        if (!$c->stash->{$rs_name}) { next; }
        my $rs = $c->stash->{$rs_name};
        while (my $row = $rs->next) {
            my $rpt_key = $row->rpt_key;
            $wh_rl_map->{$rpt_key} = 1;
            if (!exists  $rl_map->{$rpt_key}) {
                $rl_map->{$rpt_key} = undef;
            }
        }
        $rs->reset;
    }
    return $wh_rl_map;
}

sub _data2stash {
    my ($self, $c, $collection) = @_;

    my $rl_map = $collection->run_lane_collections;
    my @rl_map_keys = keys %{$rl_map};
    my $has_plexes = npg_qc::autoqc::role::rpt_key->has_plexes(\@rl_map_keys);
    my $wh_rl_map = $self->_rl_map_append($c, $rl_map);

    if ($c->stash->{'sample_link'} && $has_plexes && scalar keys %{$wh_rl_map}) {
        foreach my $key (keys %{$rl_map}) {
            if (!exists $wh_rl_map->{$key}) {
                delete $rl_map->{$key};
            }
        }
    }
    $c->stash->{'rl_map'}         = $rl_map;
    $c->stash->{'has_plexes'}     = $has_plexes;
    $c->stash->{'collection_all'} = $collection;
    $c->stash->{'template'}       = q[ui_lanes/library_lanes.tt2];
    return;
}

sub _display_libs {
    my ($self, $c, $where, $no_plexes) = @_;

    if (!keys %{$where}) {
        croak 'The WHERE hash is empty';
    }
    my ($key, $value) = each %{$where};
    if (!$key) {
        croak 'Column is an empty string in the WHERE hash';
    }

    if ($value) {
        $c->stash->{'rs'} = $c->model('WarehouseDB')->resultset('NpgInformation')->search($where);
        if (!$no_plexes) {
            $c->stash->{'plex_rs'}  = $c->model('WarehouseDB')->resultset('NpgPlexInformation')->search($where);
        }

        $c->stash->{'db_lookup'} = 1;
        my $retrieve_option = !$no_plexes ? $ALL : $LANES;

        my $run_lanes = $self->_wh_rows2run_lane_pairs($c);
        my $collection = $c->model('Check')->load_lanes($run_lanes, $c->stash->{'db_lookup'}, $retrieve_option, $c->model('NpgDB')->schema);
        $c->stash->{'sample_link'} = 1;
        $self->_data2stash($c, $collection);
        $c->stash->{'show_total'} = 1;
    } else {
        $c->stash->{'template'} = q[ui_lanes/library_lanes.tt2];
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
    my $collection =  $c->model('Check')->load_lanes($run_lanes, $c->stash->{'db_lookup'}, $retrieve_option, $c->model('NpgDB')->schema);

    my $where = {id_run => $id_runs};
    if (scalar @{$lanes}) { $where->{position} = $lanes };
    my $model = $c->model('WarehouseDB');
    if ($retrieve_option != $PLEXES) {
        $c->stash->{'rs'} = $model->resultset('NpgInformation')->search($where);
    }
    if ($retrieve_option != $LANES) {
        $c->stash->{'plex_rs'} = $model->resultset('NpgPlexInformation')->search($where);
    }
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
        $c->stash->{'title'} = $title;
    }

    if ($retrieve_option ne $ALL) {
        $c->stash->{'show_total'} = 1;
    }

    return;
}

=head2 base 

Action for the base controller path

=cut
sub base :Chained('/') :PathPart('checks') :CaptureArgs(0)
{
    my ($self, $c) = @_;
    $c->stash->{'util'}             = Moose::Meta::Class->create_anon_class(
                      roles => ['npg_qc::autoqc::role::rpt_key'])->new_object();
    $c->stash->{'rl_map'}           = {};
    $c->stash->{'db_lookup'}        = 1;
    $c->stash->{'env_dev'}          = $ENV{dev};
    $c->stash->{'run_view'}         = 0;
    $c->stash->{'run_from_staging'} = 0;
    return;
}

=head2 index 

index page

=cut
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{'title'} = q[NPG SeqQC - visualization and datamining for sequence quality control];
    $c->stash->{'template'} = q[about.tt2];
    return;
}

=head2 about 

qc checks info page

=cut
sub about :Path('about') :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{'title'} = q[NPG SeqQC: about QC checks];
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
    $c->stash->{'title'}     = qq[Results for run $id_run];
    $c->stash->{'run_view'}  = 1;
    $c->stash->{'id_run'}    = $id_run;
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
    $c->stash->{'db_lookup'}        = 0;
    $c->stash->{'title'}            = qq[Staging results for run $id_run];
    $c->stash->{'run_from_staging'} = 1;
    $c->stash->{'run_view'}         = 1;
    $c->stash->{'id_run'}           = $id_run;
    $self->_display_run_lanes($c, {run => [$id_run],} );
    return;
}

=head2 checks_from_path

Fetches the checks collection from a given path

=cut
sub checks_from_path :Chained('base') :PathPart('path') :Args(0) {
  my ($self, $c) = @_;

  if ($c->request->query_parameters->{path}) {
      my $path_arg = $c->request->query_parameters->{path};
      my @path;
      if (!ref $path_arg) {
          @path = ($path_arg);
      } else {
          @path = @{$path_arg};
      }

      $c->stash->{'title'} = q[Results from ] . join q[,], @path;
      my $collection = $c->model('Check')->load_from_path(@path);
      $self->_data2stash($c, $collection);
      $c->stash->{'db_lookup'} = 0;
      $c->stash->{'path_list'} = [@path];
      $c->stash->{'template'} = q[ui_lanes/library_lanes.tt2];
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

    if (defined $c->request->query_parameters->{name}) {
        my $lib_names = $c->request->query_parameters->{name};
        if (!ref $lib_names) {
            $lib_names = [$lib_names];
        }
        $c->stash->{'title'} = q[Libraries: ] . join q[, ], map {q['].$_.q[']} @{$lib_names};
        $self->_display_libs($c, { 'me.asset_name' => $lib_names,});
    } else {
        $c->stash->{error_message} = q[This is an invalid URL];
        $c->detach(q[Root], q[error_page]);
    }
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
    my ( $self, $c, $sample_id) = @_;

    $self->_test_positive_int($c, $sample_id);

    my $row = $c->model('WarehouseDB')->resultset('CurrentSample')->search(
         {internal_id => $sample_id,}
    )->next;
    if (!$row) {
        $c->stash->{error_message} = qq[Unknown sample id $sample_id];
        $c->detach(q[Root], q[error_page]);
        return;
    }

    my $sample_name = $row->sample_name;
    $self->_display_libs($c, { 'me.sample_id' => [$sample_id],});
    $c->stash->{'title'} = qq[Sample '$sample_name'];
    return;
}

=head2 studies

Studies page - retained in order not to change dispatch type for a study

=cut
sub studies :Chained('base') :PathPart('studies') :Args(0) {
    my ($self, $c) = @_;
    $c->stash->{error_message} = q[This is an invalid URL];
    $c->detach(q[Root], q[error_page]);
    return;
}

=head2 study

Study page

=cut
sub study :Chained('base') :PathPart('studies') :Args(1) {
    my ( $self, $c, $study_id) = @_;

    $self->_test_positive_int($c, $study_id);

    my $row = $c->model('WarehouseDB')->resultset('CurrentStudy')->search(
      { internal_id => $study_id, },
      { columns => [qw/internal_id name/], distinct => 1, },
    )->next;

    if (!$row) {
        $c->stash->{error_message} = qq[Unknown study id $study_id];
        $c->detach(q[Root], q[error_page]);
        return;
    }

    $c->stash->{'title'}  = q[Study '] . $row->study_name  . q['];
    $self->_display_libs($c, { 'me.study_id' => $study_id,});
    return;
}

no Moose;
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

=item Readonly

=item English

=item Carp

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
