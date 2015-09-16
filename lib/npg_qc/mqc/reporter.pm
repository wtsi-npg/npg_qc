#########
# Author:        Jennifer Liddle
# Created:       Friday 13th February 2015
#

package npg_qc::mqc::reporter;

use Moose;
use namespace::autoclean;
use Carp;
use POSIX qw(strftime);
use LWP::UserAgent;
use HTTP::Request;
use Try::Tiny;
use Readonly;

use st::api::base;
use npg_qc::Schema;
use WTSI::DNAP::Warehouse::Schema;

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

has 'mlwh_schema' => ( isa        => 'WTSI::DNAP::Warehouse::Schema',
                       is         => 'ro',
                       required   => 0,
                       lazy_build => 1,
                       metaclass  => 'NoGetopt',
);
sub _build_mlwh_schema {
  my $self = shift;
  return WTSI::DNAP::Warehouse::Schema->connect();
}

has 'verbose' => ( isa => 'Bool', is => 'ro', default => 0, documentation => 'print verbose messages');
has 'report_gclp' => ( isa => 'Bool', is => 'ro', default => 0, documentation => 'show warning for glcp runs');

sub load {
  my $self = shift;

  my $rs = $self->qc_schema->resultset('MqcOutcomeEnt')->get_ready_to_report();
  while (my $outcome = $rs->next()) {

    my $lane_id;
    my $from_gclp;
    my $details = sprintf 'run %i position %i', $outcome->id_run, $outcome->position;
    my $product_metric;
    try {
      my $where = {'me.id_run'=>$outcome->id_run,
                   'me.position'=>$outcome->position,
                   'me.tag_index'=> { q[!=], undef },
                   'iseq_flowcell.entity_type' => {q[!=], 'library_indexed_spike'}};
      my $rswh = $self->mlwh_schema->resultset('IseqProductMetric')->search($where, { prefetch => 'iseq_flowcell',
                                                                                      order_by => qw[ me.id_run me.position me.tag_index ]
                                                                                    },
      );
      $product_metric = $rswh->next;
    } catch {
      _log(qq(Error retrieving mlwarehouse data for $details: $_));
    };

    if ($product_metric && $product_metric->iseq_flowcell) {
      my $iseq_flowcell = $product_metric->iseq_flowcell;
      $lane_id   = $iseq_flowcell->lane_id;
      $from_gclp = $iseq_flowcell->from_gclp;
    } else {
      _log(qq[No mlwarehouse data for $details]);
      next;
    }

    if ($from_gclp) {
      if ($self->report_gclp) {
        _log(qq[GCLP run, nothing to do for $details.]);
      }
    } elsif ($lane_id) {
      my $result = $outcome->is_accepted() ? 'pass' : 'fail';
      my $url = $self->_create_url($lane_id, $result);
      if ($self->verbose) {
        _log(qq(Sending outcome for $details to $url));
      }
      my $error_txt = $self->_report($lane_id, $result, $url);
      if ($error_txt) {
        _log($error_txt);
      } else {
        $outcome->update_reported();
      }
    } else {
      _log(qq(Lane id is not set for $details));
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
    my $m = sprintf 'Response code %i : %s : %s',
      $resp->code,
      $resp->message || q(),
      $resp->content || q();
    return $m;
  }
  return q();
}

sub _log {
  my $txt = shift;
  my $time = strftime '%Y-%m-%dT%H:%M:%S', localtime;
  warn "$time: $txt\n";
  return;
}

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

=head2 mlwh_schema - an attribute; the schema to use for ml warehouse database. Defaults to WTSI::DNAP::Warehouse::Schema

=head2 load - method to perform the reading and updating

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item MooseX::Getopt

=item Carp

=item POSIX qw(strftime)

=item LWP::UserAgent

=item HTTP::Request

=item Try::Tiny

=item Readonly

=item st::api::base

=item npg_qc::Schema

=item WTSI::DNAP::Warehouse::Schema

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
