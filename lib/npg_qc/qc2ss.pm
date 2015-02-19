#########
# Author:        Jennifer Liddle
# Created:       Friday 13th February 2015
#

package npg_qc::qc2ss;

use strict;
use warnings;
use Moose;
use Carp;
use English qw{-no_match_vars};
use Readonly;

use st::api::base;
use npg_qc::Schema;
use npg::api::request;

with 'MooseX::Getopt';

our $VERSION = '0';

has 'qc_schema' => ( isa        => 'npg_qc::Schema',
                     is         => 'ro',
                     required   => 0,
                     lazy_build => 1,
                   );

sub _build_qc_schema {
  my $self = shift;
  return npg_qc::Schema->connect();
}

has 'wh_schema' => ( isa        => 'npg_warehouse::Schema',
                     is         => 'ro',
                     required   => 0,
                     lazy_build => 1,
                   );

sub _build_wh_schema {
  my $self = shift;
  return npg_warehouse::Schema->connect();
}

has 'lims_url' => ( isa => 'Str',
                    is => 'ro',
                    required => 0,
                    lazy_build => 1,
                  );

sub _build_lims_url {
  my $self = shift;
  return st::api::base->live_url();
}

has 'nPass' => ( isa => 'Int', is => 'rw', default => 0, );
has 'nFail' => ( isa => 'Int', is => 'rw', default => 0, );
has 'nError' => ( isa => 'Int', is => 'rw', default => 0, );

sub load {
  my $self = shift;

  my $rs = $self->qc_schema->resultset('MqcOutcomeEnt')->get_ready_to_report();
  while (my $outcome = $rs->next()) {
    my @wrs = $self->wh_schema->resultset('NpgInformation')->search({'id_run' => $outcome->id_run, 'position' => $outcome->position});
    if ((scalar @wrs) == 0) { croak q(Can't find any NpgInformation for run ).$outcome->id_run .' position '. $outcome->position; }
    my @rrs = $self->wh_schema->resultset('CurrentRequest')->search({'internal_id'=>$wrs[0]->request_id});
    if ((scalar @rrs) == 0) { croak q(Can't find CurrentRequest ID ) . $wrs[0]->request_id . ' for mqc_outcome_ent ' . $outcome->id_mqc_outcome_ent; }

    my $result;
    if ($outcome->is_accepted()) {
      $result = 'pass_qc_state';
      $self->nPass($self->nPass + 1);
    } else {
      $result = 'fail_qc_state';
      $self->nFail($self->nFail+1);
    }
    my $ok = eval {
      npg::api::request->new()->make($self->lims_url.q[/npg_actions/assets/].$rrs[0]->target_asset_internal_id.q(/).$result, q[POST]);
      1;
    };
    if (!$ok) {
      carp "Error updating LIMS: $EVAL_ERROR";
      $self->nError($self->nError+1);
    } else {
      $outcome->update_reported();
    }
  }
  return;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

npg_qc::qc2ss

=head1 SYNOPSIS

 npg_qc::qc2ss->new()->load();

=head1 DESCRIPTION

Reads all the QC records which need to have a pass or fail sent to LIMS, and sends them.

=head1 SUBROUTINES/METHODS

=head2 qc_schema - an attribute; the schema to use for the qc database. Defaults to npg_qc::Schema

=head2 wh_schema - an attribute; the schema to use for the warehouse database. Defaults to npg_warehouse::Schema

=head2 lims_url - an attribute; the URL to use to update the LIMS. Defaults to st::api::base->live_url

=head2 nPass - an attribute; the number of QC records which are marked as 'Pass'

=head2 nFail - an attribute; the number of QC records which are marked as 'Fail'

=head2 nError - an attribute; the number of QC records which failed to update for some reason

=head2 load - method to perform the reading and updating

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

Moose
MooseX::Getopt
Carp
English qw{-no_match_vars}
st::api::base;
npg_qc::Schema;
npg::api::request;

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
