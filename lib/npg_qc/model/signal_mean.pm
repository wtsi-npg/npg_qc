#########
# Author:        ajb
# Maintainer:    $Author$
# Created:       2008-06-10
# Last Modified: $Date$
# Id:            $Id$
# Source:        $Source: /repos/cvs/webcore/SHARED_docs/cgi-bin/docrep,v $
# $HeadURL$
#

package npg_qc::model::signal_mean;
use strict;
use warnings;
use English qw{-no_match_vars};
use Carp;
use Statistics::Lite qw(:all);
use base qw(npg_qc::model);
use npg_qc::model::run_tile;
use Readonly;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mxs; $r; };

Readonly our $ALL_CALL_Y_GA1 => 15_000;
Readonly our $ALL_CALL_Y_GA2 => 1_500;
Readonly our $GA1_TILE_COUNT_ONE_END => 8 * 330;
Readonly our $GA1_TILE_COUNT_BOTH_ENDS => 16 * 330;
Readonly our $CYCLE_POS => 0;
Readonly our $A_POS => 1;
Readonly our $C_POS => 2;
Readonly our $G_POS => 3;
Readonly our $T_POS => 4;

__PACKAGE__->mk_accessors(__PACKAGE__->fields());

sub fields {
  return qw(
            id_signal_mean
            id_run
            position
            all_a
            all_c
            all_g
            all_t
            base_a
            base_c
            base_g
            base_t
            call_a
            call_c
            call_g
            call_t
            cycle
          );
}

sub init {
  my $self = shift;

  if($self->id_run() &&
     $self->position() &&
     $self->cycle() &&
     !$self->id_signal_mean()) {

    my $query = q(SELECT id_signal_mean
                  FROM signal_mean
                  WHERE id_run = ?
                  AND position = ?
                  AND cycle = ?
                 );

    my $ref   = [];

    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->id_run(), $self->position(), $self->cycle());
      1;
    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->id_signal_mean($ref->[0]->[0]);
    }
  }
  return 1;
}
sub rescale_y {
  my ($self, $rescale) = @_;
  if ($rescale) {
    $self->{rescale_y} = $rescale;
  }
  if (!$self->{rescale_y}) {
    my $run_tiles = $self->run_tiles();
    $self->{rescale_y} = $ALL_CALL_Y_GA2;
    if (scalar@{$run_tiles} == $GA1_TILE_COUNT_BOTH_ENDS || scalar@{$run_tiles} == $GA1_TILE_COUNT_ONE_END) {
      $self->{rescale_y} = $ALL_CALL_Y_GA1;
    }
  }
  return $self->{rescale_y};
}

sub signal_means {
  my $self = shift;
  return $self->gen_getall();
}

sub signal_means_by_run_and_position {
  my ($self, $position) = @_;
  my $id_run = $self->{id_run};
  my $query = q{SELECT * FROM signal_mean WHERE id_run = ? AND position = ? ORDER BY position, cycle};
  return $self->gen_getarray(ref$self, $query, $id_run, $position);
}

sub signal_means_by_run {
  my ($self) = @_;
  my $id_run = $self->{id_run};
  my $ref = ref$self;
  my $query = q{SELECT * FROM signal_mean WHERE id_run = ? ORDER BY position, cycle};
  my $array = $self->gen_getarray($ref, $query, $id_run);
  if (!$array->[0]) {
    my $tile_all_obj = npg_qc::model::tile_all->new({
      util => $self->util(),
    });
    $array = $tile_all_obj->calculate_signal_means($id_run);
    foreach my $row (@{$array}) {
      my $temp = $ref->new({
        util => $self->util(),
      });
      foreach my $field ($self->fields()) {
        next if $field eq 'id_signal_mean';
        $temp->$field($row->{$field});
      }
      $row = $temp;
    }
  }
  my $held_row = shift @{$array};
  my $cycle = $held_row->cycle();
  my $return_array;
  foreach my $row (@{$array}) {
    if ($row->cycle() != $cycle) {
      push @{$return_array}, $held_row;
      $cycle = $row->cycle();
    }
    $held_row = $row;
    $row = undef;
  }
  return $return_array;
}

sub data_for_merge_ivc {
  my ($self) = @_;

  my $data = $self->signal_means_by_run();
  my $data_by_position = {};

  foreach my $row (@{$data}) {
    push @{$data_by_position->{all}->{$row->position}},  [$row->cycle(), $row->all_a(),  $row->all_c(),  $row->all_g(),  $row->all_t() ];
    push @{$data_by_position->{call}->{$row->position}}, [$row->cycle(), $row->call_a(), $row->call_c(), $row->call_g(), $row->call_t()];
    push @{$data_by_position->{base}->{$row->position}}, [$row->cycle(), $row->base_a(), $row->base_c(), $row->base_g(), $row->base_t()];
  }

  my $return_array = [];

  foreach my $type (qw(all call base)) {
    my $type_array = [];
    foreach my $pos (sort keys %{$data_by_position->{$type}}) {
      my $pos_array = [];
      foreach my $cycle (@{$data_by_position->{$type}->{$pos}}) {
	push @{$pos_array->[$CYCLE_POS]}, $cycle->[$CYCLE_POS];
	push @{$pos_array->[$A_POS]}, $cycle->[$A_POS];
	push @{$pos_array->[$C_POS]}, $cycle->[$C_POS];
	push @{$pos_array->[$G_POS]}, $cycle->[$G_POS];
	push @{$pos_array->[$T_POS]}, $cycle->[$T_POS];
      }
      push @{$type_array}, $pos_array;
    }
    push @{$return_array}, $type_array;
  }

  return $return_array;
}

sub totals_by_position {
  my ($self) = @_;
  my $hash = {};
  foreach my $cycle (@{$self->signal_means_by_run()}) {
    push @{$hash->{$cycle->position()}}, $cycle;
  }
  my $return_array;
  foreach my $position (sort keys %{$hash}) {
    my $temp = {};
    $temp->{position} = $position;
    foreach my $cycle (@{$hash->{$position}}) {
      push @{$temp->{cycle}}, $cycle->cycle();
      push @{$temp->{all_a}}, $cycle->all_a();
      push @{$temp->{all_c}}, $cycle->all_c();
      push @{$temp->{all_g}}, $cycle->all_g();
      push @{$temp->{all_t}}, $cycle->all_t();
      push @{$temp->{call_a}}, $cycle->call_a();
      push @{$temp->{call_c}}, $cycle->call_c();
      push @{$temp->{call_g}}, $cycle->call_g();
      push @{$temp->{call_t}}, $cycle->call_t();
      push @{$temp->{base_a}}, $cycle->base_a();
      push @{$temp->{base_c}}, $cycle->base_c();
      push @{$temp->{base_g}}, $cycle->base_g();
      push @{$temp->{base_t}}, $cycle->base_t();
    }
    push @{$return_array}, $temp;
  }
  return $return_array;
}

sub tabulate_totals_by_position {
  my ($self) = @_;
  my $return_array = [];
  foreach my $lane (@{$self->totals_by_position()}) {
    my $array_count = scalar@{$lane->{cycle}} - 1;
    for my $i (0..$array_count) {
      push @{$return_array}, [$lane->{position},
                              $lane->{cycle}->[$i],
                              $lane->{all_a}->[$i],
                              $lane->{all_c}->[$i],
                              $lane->{all_g}->[$i],
                              $lane->{all_t}->[$i],
                              $lane->{call_a}->[$i],
                              $lane->{call_c}->[$i],
                              $lane->{call_g}->[$i],
                              $lane->{call_t}->[$i],
                              $lane->{base_a}->[$i],
                              $lane->{base_c}->[$i],
                              $lane->{base_g}->[$i],
                              $lane->{base_t}->[$i]];
    }
  }
  return $return_array;
}

sub all {
  my ($self, $position) = @_;
  my $totals_by_position = $self->totals_by_position();
  my $full_data = $totals_by_position->[$position-1];
  return [$full_data->{cycle}, $full_data->{all_a}, $full_data->{all_c}, $full_data->{all_g}, $full_data->{all_t}];
}

sub call {
  my ($self, $position) = @_;
  my $totals_by_position = $self->totals_by_position();
  my $full_data = $totals_by_position->[$position-1];
  return [$full_data->{cycle}, $full_data->{call_a}, $full_data->{call_c}, $full_data->{call_g}, $full_data->{call_t}];
}

sub base {
  my ($self, $position) = @_;
  my $totals_by_position = $self->totals_by_position();
  my $full_data = $totals_by_position->[$position-1];
  return [$full_data->{cycle}, $full_data->{base_a}, $full_data->{base_c}, $full_data->{base_g}, $full_data->{base_t}];
}

1;
__END__
=head1 NAME

npg_qc::model::signal_mean

=head1 VERSION

$Revision$

=head1 SYNOPSIS

  my $oSignalMean = npg_qc::model::signal_mean->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - return array of fields, first of which is the primary key

  my $aFields = $oSignalMean->fields();

=head2 signal_means - returns array of all signal_mean objects

  my $aSignalMeans = $oSignalMean->signal_means();

=head2 all  - returns an array of containing arrays of cycles, all a, c, g, t signal means for a given lane position
=head2 base - returns an array of containing arrays of cycles, base a, c, g, t signal means for a given lane position
=head2 call - returns an array of containing arrays of cycles, called a, c, g, t signal means for a given lane position
=head2 signal_means_by_run - returns an array of all the signal means for a run by position and cycle
=head2 signal_means_by_run_and_position - returns an array of all the signal means for a run lane position
=head2 tabulate_totals_by_position tabulates - tabulates the data and returns an array ref containing the rows
=head2 totals_by_position - returns an conglomeration of all, call and base in one table

=head2 init
=head2 data_for_merge_ivc - returns an array of all the IVC data for a run, ordered by the graphs all/call/base and position

=head2 rescale_y - returns the y-scale max required for the ivc graphs, either the user determined, or a default based on machine platform used

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::model
Statistics::Lite
Carp
English

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
