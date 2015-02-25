#########
# Author:        Jennifer Liddle
# Created:       Friday 13th February 2015
#

package npg_qc::mqc::reporter;

use strict;
use warnings;
use Moose;
use Carp;
use English qw{-no_match_vars};
use Readonly;
use POSIX qw(strftime);

use st::api::base;
use st::api::lims;
use npg_qc::Schema;

with 'MooseX::Getopt';

our $VERSION = '0';

has 'qc_schema' => ( isa        => 'npg_qc::Schema',
                     is         => 'ro',
                     required   => 0,
                     lazy_build => 1,
                     metaclass => 'NoGetopt',
                   );

sub _build_qc_schema {
  my $self = shift;
  return npg_qc::Schema->connect();
}

has 'lims_url' => ( isa => 'Str',
                    is => 'ro',
                    required => 0,
                    lazy_build => 1,
                    metaclass => 'NoGetopt',
                  );

sub _build_lims_url {
  my $self = shift;
  return st::api::base->live_url();
}

has 'nPass' => ( isa => 'Int', is => 'ro', default => 0, writer => '_set_nPass', metaclass => 'NoGetopt',);
has 'nFail' => ( isa => 'Int', is => 'ro', default => 0, writer => '_set_nFail', metaclass => 'NoGetopt',);
has 'nError' => ( isa => 'Int', is => 'ro', default => 0, writer => '_set_nError', metaclass => 'NoGetopt',);

has 'verbose' => ( isa => 'Bool', is => 'rw', default => 0, documentation => 'print verbose messages');

sub load {
  my $self = shift;

  $self->_set_nPass(0);
  $self->_set_nFail(0);
  $self->_set_nError(0);

  my $rs = $self->qc_schema->resultset('MqcOutcomeEnt')->get_ready_to_report();
  while (my $outcome = $rs->next()) {
    my $lane_id = st::api::lims->new(id_run => $outcome->id_run, position => $outcome->position)->lane_id;
    if (!$lane_id) {
        $self->nError($self->nError+1);
        _log(q(Can't find lane_id for run ) . $outcome->id_run . ' position ' . $outcome->position);
        next;
    }

    my $result;
    if ($outcome->is_accepted()) {
      $result = 'pass_qc_state';
      $self->_set_nPass($self->nPass + 1);
    } else {
      $result = 'fail_qc_state';
      $self->_set_nFail($self->nFail+1);
    }

    if ($self->verbose) {
        _log('Sending outcome for run '.$outcome->id_run.' position '.$outcome->position.' to url '.$self->_create_url($lane_id,$result));
    }

    my $error_txt = $self->_report($lane_id, $result);
    if ($error_txt) {
      _log($error_txt);
      $self->_set_nError($self->nError+1);
    } else {
      $outcome->update_reported();
    }
  }
  return;
}

sub _create_url {
  my ($self, $lane_id, $result) = @_;
  return $self->lims_url.q[/npg_actions/assets/].$lane_id.q(/).$result;
}

sub _report {
  my ($self, $lane_id, $result) = @_;
  eval {
    npg::api::request->new()->make($self->_create_url($lane_id,$result), q[POST]);
    1;
  } or do {
    return "Error updating LIMS: $EVAL_ERROR";
  };
  return q( );
}

sub _log {
    my $txt = shift;
    my $time = strftime '%Y-%m-%dT%H:%M:%S', localtime;
    warn "$time: $txt\n";
    return;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

npg_qc::mqc::reporter

=head1 SYNOPSIS

 npg_qc::mqc::reporter->new()->load();

=head1 DESCRIPTION

Reads all the QC records which need to have a pass or fail sent to LIMS, and sends them.

=head1 SUBROUTINES/METHODS

=head2 qc_schema - an attribute; the schema to use for the qc database. Defaults to npg_qc::Schema

=head2 lims_url - an attribute; the URL to use to update the LIMS. Defaults to st::api::base->live_url

=head2 nPass - an attribute; the number of QC records which are marked as 'Pass'

=head2 nFail - an attribute; the number of QC records which are marked as 'Fail'

=head2 nError - an attribute; the number of QC records which failed to update for some reason

=head2 load - method to perform the reading and updating

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item English qw{-no_match_vars}

=item st::api::base;

=item npg_qc::Schema;

=item npg::api::request;

=item POSIX qw(strftime);

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Jennifer Liddle <js10@sanger.ac.uk>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
