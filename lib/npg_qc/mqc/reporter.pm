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

has 'qc_schema' => (
  isa        => 'npg_qc::Schema',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
  metaclass  => 'NoGetopt',
);
sub _build_qc_schema {
  my $self = shift;
  return npg_qc::Schema->connect();
}

has 'mlwh_schema' => (
  isa        => 'WTSI::DNAP::Warehouse::Schema',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
  metaclass  => 'NoGetopt',
);
sub _build_mlwh_schema {
  my $self = shift;
  return WTSI::DNAP::Warehouse::Schema->connect();
}

has 'verbose'     => (
  isa           => 'Bool',
  is            => 'ro',
  default       => 0,
  documentation => 'print verbose messages, defaults to false',
);

has 'warn_gclp' => (
  isa           => 'Bool',
  is            => 'ro',
  default       => 0,
  documentation => 'show warning for glcp runs, defaults to false',
);

has '_ua'     => ( isa           => 'LWP::UserAgent',
                   is            => 'ro',
                   lazy_build    => 1,
);
sub _build__ua {
  my $ua = LWP::UserAgent->new;
  $ua->env_proxy();            # agent has to respect our proxy env settings
  $ua->agent(join q[/], __PACKAGE__, $VERSION);
  $ua->timeout($HTTP_TIMEOUT); # set a one minute timeout
  return $ua;
}

sub load {
  my $self = shift;

  my $rs = $self->qc_schema->resultset('MqcOutcomeEnt')->get_ready_to_report();
  while (my $outcome = $rs->next()) {

    my $lane_id;
    my $from_gclp;
    my $details = sprintf 'run %i position %i', $outcome->id_run, $outcome->position;
    try {
      my $where = {'me.id_run'                 => $outcome->id_run,
                   'me.position'               => $outcome->position,
                   'iseq_flowcell.entity_type' => {q[!=], 'library_indexed_spike'} };
      my $rswh = $self->mlwh_schema
                      ->resultset('IseqProductMetric')
                      ->search($where, { prefetch => 'iseq_flowcell',
                                         order_by => { -desc => 'me.tag_index' },
                                       },
      );
      while (my $product_metric_row = $rswh->next) {
        my $fc     = $product_metric_row->iseq_flowcell;
        $lane_id   = $fc->lane_id;
        if( $fc && $lane_id ) {
          $from_gclp = $fc->from_gclp;
          last;
        }
      }
    } catch {
      _log(qq(Error retrieving data for $details: $_));
    };

    if (!$lane_id || !defined $from_gclp ) {
      _log(qq[No LIMs data for $details]);
      next;
    }

    if ($from_gclp) {
      if ($self->warn_gclp) {
        _log(qq[GCLP run, cannot report $details]);
      }
    } else {
      my $qc_result = $outcome->is_accepted() ? 'pass' : 'fail';
      if ( $self->_report(
             $self->_payload($lane_id, $qc_result),
             $self->_url($lane_id, $qc_result)) ) {
        $outcome->update_reported();
      }
    }
  }
  return;
}

sub _url {
  my ($self, $lane_id, $qc_result) = @_;
  return st::api::base->lims_url() .
         q[/npg_actions/assets/].$lane_id.q(/).$qc_result.'_qc_state';
}

sub _payload {
  my ($self, $lane_id, $qc_result) = @_;
  return q(<?xml version="1.0" encoding="UTF-8"?>) .
           q(<qc_information>) .
            qq(<message>Asset $lane_id  ${qc_result}ed manual qc</message>) .
           q(</qc_information>);
}

sub _report {
  my ($self, $payload, $url) = @_;

  my $req = HTTP::Request->new(POST => $url);
  $req->header('content-type' => 'text/xml');
  $req->content($payload);
  if ($self->verbose) {
    _log(qq(Sending $payload to $url));
  }

  my $resp = $self->_ua->request($req);
  my $result = $resp->is_success;
  if (!$result) {
    _log(sprintf 'Response code %i : %s : %s',
                                $resp->code,
                                $resp->message || q(),
                                $resp->content || q());
  }
  return $result;
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

  Reporter for manual QC results. The lane-level results are posted
  to a Sequencescape URL. GCLP results are not reported. 

=head1 SUBROUTINES/METHODS

=head2 verbose

  Boolean verbose flag, false by default.

=head2 warn_gclp

  Boolean flag switching on warnings when a GCLP lane is encounted,
  false by default.

=head2 qc_schema

  An attribute - the schema to use for the qc database.
  Defaults to npg_qc::Schema,

=head2 mlwh_schema

  An attribute - the schema to use for ml warehouse database.
  Defaults to WTSI::DNAP::Warehouse::Schema.

=head2 load
  
  Rertrieves all unreported lane-level manual QC results, filters out
  GCLP results and tries to report the remaining to a Sequencescape URL.
  If successful, marks the manual qc outcome as reported by setting a
  time stamp. Unsuccessfull attempts are logged.

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
