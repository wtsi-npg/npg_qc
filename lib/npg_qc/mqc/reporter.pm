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
Readonly::Scalar my $CONTENT_TYPE => 'text/xml';

has 'qc_schema' => (
  isa        => 'npg_qc::Schema',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
  metaclass  => 'NoGetopt',
);
sub _build_qc_schema {
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

has 'dry_run' => (
  isa           => 'Bool',
  is            => 'ro',
  default       => 0,
  documentation => 'dry run',
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

has '_data4reporting' => ( isa           => 'HashRef',
                           is            => 'ro',
                           lazy_build    => 1,
);
sub _build__data4reporting {
  my $self = shift;

  my $rs = $self->qc_schema->resultset('MqcOutcomeEnt')->get_ready_to_report();
  my $product_rs = $self->mlwh_schema->resultset('IseqProductMetric');
  my $data = {};

  while (my $outcome = $rs->next()) {

    my $lane_id;
    my $from_gclp;
    my $id_run   = $outcome->id_run;
    my $position = $outcome->position;

    my $rswh = $product_rs->search(
                {
                 'me.id_run'    => $id_run,
                 'me.position'  => $position,
                },
                {
                  'prefetch' => 'iseq_flowcell',
                  'order_by' => { -desc => 'me.tag_index' },
                });

    while ( my $product_row = $rswh->next ) {
      my $fc = $product_row->iseq_flowcell;
      if( $fc ) {
        if ( $fc->is_control ) {
          next;
        }
        $lane_id   = $fc->lane_id;
        $from_gclp = $fc->from_gclp;
        if ( $lane_id ) {
          last;
        }
      }
    }

    if ( $from_gclp ) {
      if ( $self->warn_gclp ) {
        $self->_log(qq[GCLP run, cannot report run $id_run lane $position]);
      }
      next;
    }

    if ( !$lane_id )  {
      $self->_log(qq[No lane id for run $id_run lane $position]);
      next;
    }

    my $qc_outcome = $outcome->is_accepted() ? 'pass' : 'fail';
    $data->{$id_run}->{$position} = {
                        'outcome' => $qc_outcome,
                        'row'     => $outcome,
                        'lane_id' => $lane_id,
                                    };
  }
  return $data;
}

sub load {
  my $self = shift;

  my $data = $self->_data4reporting();
  foreach my $id_run (sort { $a <=> $b} keys %{$data}) {
    foreach my $position (sort { $a <=> $b} keys %{$data->{$id_run}} ) {
      sleep 1; # To help LIMs server
      my $lane_data = $data->{$id_run}->{$position};
      my $qc_result = $lane_data->{'outcome'};
      my $lane_id   = $lane_data->{'lane_id'};
      $self->_log(qq[Will report $qc_result for run $id_run lane $position, id $lane_id]);
      my $reported = $self->_report(
           $self->_payload($lane_id, $qc_result),
           $self->_url($lane_id, $qc_result),
                                   );
      if ($reported && !$self->dry_run) {
        my $outcome = $lane_data->{'row'};
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
  $req->header('content-type' => $CONTENT_TYPE);
  $req->header('accept'       => $CONTENT_TYPE);
  $req->content($payload);
  if ($self->verbose) {
    $self->_log(qq(Sending $payload to $url));
  }

  my $result = 1;
  if (!$self->dry_run) {
    my $resp = $self->_ua->request($req);
    $result = $resp->is_success;
    if (!$result) {
      $self->_log(sprintf 'Response code %i : %s : %s',
                                $resp->code,
                                $resp->message || q(),
                                $resp->content || q());
    }
  }
  return $result;
}

sub _log {
  my ($self, $txt) = @_;
  my $time = strftime '%Y-%m-%dT%H:%M:%S', localtime;
  my $m = "$time: $txt";
  if ($self->dry_run) {
    $m = 'DRY RUN: ' . $m;
  }
  warn "$m\n";
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

=head2 dry_run

  Dry run flag. No reporting, no marking as reported in the qc database.

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
