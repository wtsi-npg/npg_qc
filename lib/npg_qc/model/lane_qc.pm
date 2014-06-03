#########
# Author:        ajb
# Created:       2008-06-25
#

package npg_qc::model::lane_qc;
use strict;
use warnings;
use base qw(npg_qc::model);
use Readonly;
use English qw(-no_match_vars);
use Carp;

our $VERSION = '0';

Readonly our $PERCENTAGE               => 100;
Readonly our $CLUSTER_GA1_RAW_MINIMUM  => 15_000;
Readonly our $CLUSTER_GA1_RAW_MAX      => 50_000;
Readonly our $CLUSTER_GA2_RAW_MINIMUM  => 100_000;
Readonly our $CLUSTER_GA2_RAW_MAX      => 200_000;
Readonly our $PERC_PF_MINIMUM          => 50;
Readonly our $PERC_ERROR_RATE_MINIMUM  => 2;
Readonly our $HIGH_TWENTIETH_CYCLE_MAX => 100;
Readonly our $LOW_TWENTIETH_CYCLE_MIN  => 60;
Readonly our $TILES_ON_GA2             => 100;

__PACKAGE__->mk_accessors(__PACKAGE__->fields());

sub fields {
  return qw(
            id_lane_qc
            id_run_tile
            end
            clusters_raw
            av_1st_cycle_int_pf
            av_perc_intensity_after_20_cycles_pf
            perc_pf_clusters
            perc_align_pf
            av_alignment_score_pf
            perc_error_rate_pf
          );
}

sub tile_pf_cluster_count {
  my ($self) = @_;
  if (!$self->id_lane_qc()) {
    croak 'tile_pf_cluster_count cannot be performed with no data';
  }
  return sprintf '%02d', $self->clusters_raw * $self->perc_pf_clusters / $PERCENTAGE;
}

sub init {
  my ($self) = @_;

  if ($self->{id_run_tile} && !$self->{id_lane_qc}) {
    my $query = q(SELECT id_lane_qc
                  FROM   lane_qc
                  WHERE  id_run_tile = ?);
    my $ref   = [];
    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->id_run_tile());
      1;
    } or do {
      carp $EVAL_ERROR;
      return;
    };
    if(@{$ref}) {
      $self->{'id_lane_qc'} = $ref->[0]->[0];
    }
  }
  return 1;
}

sub lane_qcs {
  my $self = shift;
  return $self->gen_getall();
}


sub run_tile {
  my $self  = shift;
  my $pkg   = 'npg_qc::model::run_tile';
  return $pkg->new({
		    'util' => $self->util(),
		    'id_run_tile' => $self->id_run_tile(),
		   });
}

sub lane_qcs_per_run {
  my ($self, $id_run) = @_;
  my $pkg = ref$self;

  my @fields_wanted = $self->fields();
  shift @fields_wanted;

  my $query = qq{SELECT @{[join q(, ), map { "lqc.$_ AS $_" }  @fields_wanted]}, rt.tile AS tile, rt.position AS position
                 FROM   @{[$pkg->table]} lqc,
                        run_tile rt
                 WHERE  rt.id_run = ?
                 AND    rt.id_run_tile = lqc.id_run_tile
                 ORDER BY lqc.end, rt.position, rt.tile};
  return $self->gen_getarray($pkg, $query, $id_run);
}

sub raw_clusters {
  my ($self, $arg_refs) = @_;

  my $query = q{SELECT lqc.clusters_raw, rt.position, rt.tile 
                FROM   lane_qc lqc,
                       run_tile rt
                WHERE  rt.id_run = ?
                AND    rt.id_run_tile = lqc.id_run_tile
                AND    lqc.end = ?
                ORDER BY rt.position, rt.tile};

  $arg_refs->{query} = $query;

  return $self->heatmap_data_refactor($arg_refs);
}


sub heatmap_data_refactor {
  my ($self, $arg_refs) = @_;

  my $id_run = $arg_refs->{id_run};
  my $end    = $arg_refs->{end};
  my $query  = $arg_refs->{query};

  my $dbh = $self->util->dbh();
  my $sth = $dbh->prepare($query);
  $sth->execute($id_run, $end);

  my $return_dataset = [];

  while (my @row = $sth->fetchrow_array) {
    my $position  = $row[1] - 1;
    push @{$return_dataset->[$position]}, $row[0];
  }
  return $return_dataset;
}

sub first_cycle_intensities {
  my ($self, $arg_refs) = @_;

  my $query = q{SELECT lqc.av_1st_cycle_int_pf, rt.position, rt.tile 
                FROM   lane_qc lqc,
                       run_tile rt
                WHERE  rt.id_run = ?
                AND    rt.id_run_tile = lqc.id_run_tile
                AND    lqc.end = ?
                ORDER BY rt.position, rt.tile};

  $arg_refs->{query} = $query;

  return $self->heatmap_data_refactor($arg_refs);
}

sub perc_twentieth_cycles_intensities {
  my ($self, $arg_refs) = @_;

  my $query = q{SELECT lqc.av_perc_intensity_after_20_cycles_pf, rt.position, rt.tile 
                FROM   lane_qc lqc,
                       run_tile rt
                WHERE  rt.id_run = ?
                AND    rt.id_run_tile = lqc.id_run_tile
                AND    lqc.end = ?
                ORDER BY rt.position, rt.tile};

  $arg_refs->{query} = $query;

  return $self->heatmap_data_refactor($arg_refs);
}

sub pf_perc_clusters {
  my ($self, $arg_refs) = @_;

  my $query = q{SELECT lqc.perc_pf_clusters, rt.position, rt.tile 
                FROM   lane_qc lqc,
                       run_tile rt
                WHERE  rt.id_run = ?
                AND    rt.id_run_tile = lqc.id_run_tile
                AND    lqc.end = ?
                ORDER BY rt.position, rt.tile};

  $arg_refs->{query} = $query;

  return $self->heatmap_data_refactor($arg_refs);
}

sub pf_perc_align {
  my ($self, $arg_refs) = @_;

  my $query = q{SELECT lqc.perc_align_pf, rt.position, rt.tile 
                FROM   lane_qc lqc,
                       run_tile rt
                WHERE  rt.id_run = ?
                AND    rt.id_run_tile = lqc.id_run_tile
                AND    lqc.end = ?
                ORDER BY rt.position, rt.tile};

  $arg_refs->{query} = $query;

  return $self->heatmap_data_refactor($arg_refs);
}

sub pf_alignment_scores {
  my ($self, $arg_refs) = @_;

  my $query = q{SELECT lqc.av_alignment_score_pf, rt.position, rt.tile 
                FROM   lane_qc lqc,
                       run_tile rt
                WHERE  rt.id_run = ?
                AND    rt.id_run_tile = lqc.id_run_tile
                AND    lqc.end = ?
                ORDER BY rt.position, rt.tile};

  $arg_refs->{query} = $query;

  return $self->heatmap_data_refactor($arg_refs);
}

sub pf_perc_error_rates {
  my ($self, $arg_refs) = @_;

  my $query = q{SELECT lqc.perc_error_rate_pf, rt.position, rt.tile 
                FROM   lane_qc lqc,
                       run_tile rt
                WHERE  rt.id_run = ?
                AND    rt.id_run_tile = lqc.id_run_tile
                AND    lqc.end = ?
                ORDER BY rt.position, rt.tile};

  $arg_refs->{query} = $query;

  return $self->heatmap_data_refactor($arg_refs);
}

sub pf_clusters {
  my ($self, $arg_refs) = @_;

  my $query = qq{SELECT ROUND((lqc.clusters_raw*lqc.perc_pf_clusters)/$PERCENTAGE) AS pf_clusters, rt.position, rt.tile 
                 FROM   lane_qc lqc,
                        run_tile rt
                 WHERE  rt.id_run = ?
                 AND    rt.id_run_tile = lqc.id_run_tile
                 AND    lqc.end = ?
                 ORDER BY rt.position, rt.tile};

  $arg_refs->{query} = $query;

  return $self->heatmap_data_refactor($arg_refs);
}

sub tile_max {
  my ($self, $id_run) = @_;

  if (!$self->{tile_max}) {
    my $rt = npg_qc::model::run_tile->new({ util => $self->util() });
    $self->{tile_max} = $rt->tile_max($id_run);
  }

  return $self->{tile_max};
}

sub intensity_alerts {
  my ($self, $id_run) = @_;

  if (!$self->{intensity_alerts}) {

    $self->{intensity_alerts} = {};

    my $high_twentieth_cycle = {};

    my $query = qq{SELECT lqc.av_perc_intensity_after_20_cycles_pf AS value, rt.position, rt.tile, rt.id_run_tile 
                   FROM   lane_qc lqc,
                          run_tile rt
                   WHERE  rt.id_run = ?
                   AND    rt.id_run_tile = lqc.id_run_tile
                   AND    lqc.end = ?
                   AND    lqc.av_perc_intensity_after_20_cycles_pf > $HIGH_TWENTIETH_CYCLE_MAX
                   ORDER BY rt.position, rt.tile};

    eval {
           $self->alert_query_appended_to_alert_hash({
             query  => $query,
             params => [$id_run, 1],
             hash   => $high_twentieth_cycle,
             key    => 'end_1',
           });
    } or do {
      croak $EVAL_ERROR;
    };

    eval {
           $self->alert_query_appended_to_alert_hash({
             query  => $query,
             params => [$id_run, 2],
             hash   => $high_twentieth_cycle,
             key    => 'end_2',
           });
    } or do {
      croak $EVAL_ERROR;
    };

    my $low_twentieth_cycle = {};

    $query = qq{SELECT lqc.av_perc_intensity_after_20_cycles_pf AS value, rt.position, rt.tile, rt.id_run_tile 
                FROM   lane_qc lqc,
                       run_tile rt
                WHERE  rt.id_run = ?
                AND    rt.id_run_tile = lqc.id_run_tile
                AND    lqc.end = ?
                AND    lqc.av_perc_intensity_after_20_cycles_pf < $LOW_TWENTIETH_CYCLE_MIN
                ORDER BY rt.position, rt.tile};

    eval {
           $self->alert_query_appended_to_alert_hash({
             query  => $query,
             params => [$id_run, 1],
             hash   => $low_twentieth_cycle,
             key    => 'end_1',
           });
    } or do {
      croak $EVAL_ERROR;
    };

    eval {
           $self->alert_query_appended_to_alert_hash({
             query  => $query,
             params => [$id_run, 2],
             hash   => $low_twentieth_cycle,
             key    => 'end_2',
           });
    } or do {
      croak $EVAL_ERROR;
    };

    if (scalar keys %{$high_twentieth_cycle}) {
      $self->{error_alerts}->{high_twentieth_cycle} = $high_twentieth_cycle;
    }

    if (scalar keys %{$low_twentieth_cycle}) {
      $self->{error_alerts}->{low_twentieth_cycle} = $low_twentieth_cycle;
    }

    if (!scalar keys %{$self->{error_alerts}}) {
      $self->{error_alerts} = undef;
    }

  }

  return $self->{error_alerts};
}

sub error_alerts {
  my ($self, $id_run) = @_;

  if (!$self->{error_alerts}) {

    $self->{error_alerts} = {};

    my $high_pf_error_rate = {};

    my $query = qq{SELECT lqc.perc_error_rate_pf AS value, rt.position, rt.tile, rt.id_run_tile 
                   FROM   lane_qc lqc,
                          run_tile rt
                   WHERE  rt.id_run = ?
                   AND    rt.id_run_tile = lqc.id_run_tile
                   AND    lqc.end = ?
                   AND    lqc.perc_error_rate_pf > $PERC_ERROR_RATE_MINIMUM
                   ORDER BY rt.position, rt.tile};

    eval {
           $self->alert_query_appended_to_alert_hash({
             query  => $query,
             params => [$id_run, 1],
             hash   => $high_pf_error_rate,
             key    => 'end_1',
           });
    } or do {
      croak $EVAL_ERROR;
    };

    eval {
           $self->alert_query_appended_to_alert_hash({
             query  => $query,
             params => [$id_run, 2],
             hash   => $high_pf_error_rate,
             key    => 'end_2',
           });
    } or do {
      croak $EVAL_ERROR;
    };

    if (scalar keys %{$high_pf_error_rate}) {
      $self->{error_alerts}->{high_pf_error_rate} = $high_pf_error_rate;
    }

    if (!scalar keys %{$self->{error_alerts}}) {
      $self->{error_alerts} = undef;
    }

  }

  return $self->{error_alerts};
}

sub cluster_alerts {
  my ($self, $id_run) = @_;

  if (!$self->{cluster_alerts}) {

    $self->{cluster_alerts} = {};

    my ($cluster_raw_max, $cluster_raw_min);

    if ($self->tile_max($id_run) == $TILES_ON_GA2) {
      $cluster_raw_max = $CLUSTER_GA2_RAW_MAX;
      $cluster_raw_min = $CLUSTER_GA2_RAW_MINIMUM;
    } else {
      $cluster_raw_max = $CLUSTER_GA1_RAW_MAX;
      $cluster_raw_min = $CLUSTER_GA1_RAW_MINIMUM;
    }

    my $query = qq{SELECT lqc.clusters_raw AS value, rt.position, rt.tile, rt.id_run_tile 
                   FROM   lane_qc lqc,
                          run_tile rt
                   WHERE  rt.id_run = ?
                   AND    rt.id_run_tile = lqc.id_run_tile
                   AND    lqc.end = 1
                   AND    lqc.clusters_raw < $cluster_raw_min
                   ORDER BY rt.position, rt.tile};

    eval {
           $self->alert_query_appended_to_alert_hash({
             query  => $query,
             params => [$id_run],
             hash   => $self->{cluster_alerts},
             key    => 'low_raw_clusters',
           });
    } or do {
      croak $EVAL_ERROR;
    };

    $query = qq{SELECT lqc.clusters_raw AS value, rt.position, rt.tile, rt.id_run_tile
                FROM   lane_qc lqc,
                       run_tile rt
                WHERE  rt.id_run = ?
                AND    rt.id_run_tile = lqc.id_run_tile
                AND    lqc.end = 1
                AND    lqc.clusters_raw > $cluster_raw_max
                ORDER BY rt.position, rt.tile};

    eval {
           $self->alert_query_appended_to_alert_hash({
             query  => $query,
             params => [$id_run],
             hash   => $self->{cluster_alerts},
             key    => 'high_raw_clusters',
           });
    } or do {
      croak $EVAL_ERROR;
    };

    $query = qq{SELECT lqc.perc_pf_clusters AS value, rt.position, rt.tile, rt.id_run_tile
                FROM   lane_qc lqc,
                       run_tile rt
                WHERE  rt.id_run = ?
                AND    rt.id_run_tile = lqc.id_run_tile
                AND    lqc.end = 1
                AND    lqc.perc_pf_clusters < $PERC_PF_MINIMUM
                ORDER BY rt.position, rt.tile};

    eval {
           $self->alert_query_appended_to_alert_hash({
             query  => $query,
             params => [$id_run],
             hash   => $self->{cluster_alerts},
             key    => 'perc_pf_clusters',
           });
    } or do {
      croak $EVAL_ERROR;
    };

    if (!scalar keys %{$self->{cluster_alerts}}) {
      $self->{cluster_alerts} = undef;
    }

  }
  return $self->{cluster_alerts};
}

1;
__END__
=head1 NAME

npg_qc::model::lane_qc

=head1 SYNOPSIS

  my $oLaneQC = npg_qc::model::lane_qc->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - return array of fields, first of which is the primary key

  my $aFields = $oLaneQC->fields();

=head2 init - on creation, enables finding of id_lane_qc from id_run_tile

=head2 lane_qcs - returns array of all lane_qc objects

  my $aLaneQCs = $oLaneQC->lane_qcs();

=head2 run_tile - returns run_tile object that this object belongs to

  my $oRunTile = $oLaneQC->run_tile();

=head2 lane_qcs_per_run - returns all the lane quality control objects for a given run

  my $aLaneQcsPerRun = $oLaneQC->lane_qcs_per_run($id_run);

=head2 error_alerts - returns hashref of all error_alerts

  my $hErrorAlerts = $oLaneQC->error_alerts($id_run);

=head2 cluster_alerts - returns hashref of all cluster alerts

  my $hClusterAlerts = $oLaneQC->cluster_alerts($id_run);

=head2 intensity_alerts - returns hashref of all intensity alerts

  my $hIntensityAlerts = $oLaneQC->intensity_alerts($id_run);

=head2 tile_max - returns the highest tile number for given id_run

  my $iTileMax = $oLaneQC->tile_max($id_run);

=head2 tile_pf_cluster_count - returns the value of pf_cluster_count for this tile

  my $iTilePFClusterCount = $oLaneQC->tile_pf_cluster_count();

=head2 first_cycle_intensities
=head2 heatmap_data_refactor
=head2 perc_twentieth_cycles_intensities
=head2 pf_alignment_scores
=head2 pf_clusters
=head2 pf_perc_align
=head2 pf_perc_clusters
=head2 pf_perc_error_rates
=head2 raw_clusters

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::model

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown, E<lt>ajb@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Andy Brown

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
