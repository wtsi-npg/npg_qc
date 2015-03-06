#########
# Author:        Jennifer Liddle
# Created:       Friday 13th February 2015
#

package npg_qc::mqc::reporter;

use Moose;
use Carp;
use POSIX qw(strftime);
use LWP::UserAgent;
use HTTP::Request;
use Try::Tiny;
use Readonly;

use st::api::base;
use st::api::lims;
use npg_qc::Schema;

with 'MooseX::Getopt';

our $VERSION = '0';

Readonly::Scalar my $HTTP_TIMEOUT => 60;

has 'qc_schema' => ( isa        => 'npg_qc::Schema',
                     is         => 'ro',
                     required   => 0,
                     lazy_build => 1,
                     metaclass  => 'NoGetopt',
                   );

sub _build_qc_schema {
  my $self = shift;
  return npg_qc::Schema->connect();
}

has 'nPass'  => ( isa => 'Int', is => 'ro', default => 0, writer => '_set_nPass',  metaclass => 'NoGetopt',);
has 'nFail'  => ( isa => 'Int', is => 'ro', default => 0, writer => '_set_nFail',  metaclass => 'NoGetopt',);
has 'nError' => ( isa => 'Int', is => 'ro', default => 0, writer => '_set_nError', metaclass => 'NoGetopt',);

has 'verbose' => ( isa => 'Bool', is => 'ro', default => 0, documentation => 'print verbose messages');

sub load {
  my $self = shift;

  $self->_set_nPass(0);
  $self->_set_nFail(0);
  $self->_set_nError(0);

  my $rs = $self->qc_schema->resultset('MqcOutcomeEnt')->get_ready_to_report();
  while (my $outcome = $rs->next()) {
    my $lane_id;

    try {
      $lane_id = st::api::lims->new(id_run => $outcome->id_run, position => $outcome->position)->lane_id;
    } catch {
      $self->_set_nError($self->nError+1);
      _log(q(Can't find lane_id for run ) . $outcome->id_run . ' position ' . $outcome->position . q(: ) . $_);
    };

    if ($lane_id) {
      my $result;
      if ($outcome->is_accepted()) {
        $result = 'pass';
        $self->_set_nPass($self->nPass + 1);
      } else {
        $result = 'fail';
        $self->_set_nFail($self->nFail+1);
      }

      my $url = $self->_create_url($lane_id,$result);
      if ($self->verbose) {
        _log('Sending outcome for run '.$outcome->id_run.' position '.$outcome->position.' to url '.$url);
      }

      my $error_txt = $self->_report($lane_id, $result, $url);
      if ($error_txt) {
        _log($error_txt);
        $self->_set_nError($self->nError+1);
      } else {
        $outcome->update_reported();
      }
    }
  }
  return;
}

sub _create_url {
  my ($self, $lane_id, $result) = @_;
  return st::api::base->lims_url() . q[/npg_actions/assets/].$lane_id.q(/).$result.'_qc_state';
}

sub _report {
  my ($self, $lane_id, $result, $url) = @_;
  my $ua = LWP::UserAgent->new;
  $ua->env_proxy();     # agent has to respect our proxy env settings
  $ua->agent(join q[/], __PACKAGE__, $VERSION);
  $ua->timeout($HTTP_TIMEOUT);     # set a one minute timeout
  my $req = HTTP::Request->new(POST => $url);
  $req->header('content-type' => 'text/xml');
  $req->content(qq(<?xml version="1.0" encoding="UTF-8"?><qc_information><message>Asset $lane_id  ${result}ed manual qc</message></qc_information>));
  my $resp = $ua->request($req);
  if (!$resp->is_success) {
    return $resp->code . ' : ' . $resp->message . ' : ' . $resp->content;
  }
  return q();
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

=head2 nPass - an attribute; the number of QC records which are marked as 'Pass'

=head2 nFail - an attribute; the number of QC records which are marked as 'Fail'

=head2 nError - an attribute; the number of QC records which failed to update for some reason

=head2 load - method to perform the reading and updating

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::Getopt

=item Carp

=item POSIX qw(strftime)

=item LWP::UserAgent

=item HTTP::Request

=item Try::Tiny

=item Readonly

=item st::api::base

=item st::api::lims

=item npg_qc::Schema

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
