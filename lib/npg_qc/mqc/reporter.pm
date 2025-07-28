package npg_qc::mqc::reporter;

use Moose;
use namespace::autoclean;
use Carp;
use POSIX qw(strftime);
use LWP::UserAgent;
use HTTP::Request;
use Try::Tiny;
use Readonly;

extends 'npg_qc::report::common';

our $VERSION = '0';

Readonly::Scalar my $HTTP_TIMEOUT => 120;
Readonly::Scalar my $CONTENT_TYPE => 'text/xml';

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

    my $composition = $outcome->seq_composition();
    if ($composition->size > 1) {
      next;
    }
    my $component = $composition->seq_component_compositions()
                                ->first() # Safe, we have one component only.
                                ->seq_component();
    if (defined $component->tag_index || defined $component->subset) {
      croak 'Incorrectly linked outcome with id ' . $outcome->id_mqc_outcome_ent;
    }
    my $id_run   = $component->id_run;
    my $position = $component->position;

    my $rswh = $product_rs->search(
      {
       'me.id_run'    => $id_run,
       'me.position'  => $position,
       'me.tag_index' => {q[!=] => 0},
       'iseq_flowcell.entity_type' => {q[-not_in] => [qw(library_control library_indexed_spike)]},
       'iseq_flowcell.id_lims' => {q[-not_like] => 'C_GCLP%'},
       'iseq_flowcell.entity_id_lims' => {q[!=] => undef},
      },
      {
        'prefetch' => 'iseq_flowcell',
        'order_by' => { -desc => 'me.tag_index' },
      }
    );

    my $lane_id;
    while ( my $product_row = $rswh->next ) {
      my $fc = $product_row->iseq_flowcell;
      if( $fc ) {
        $lane_id   = $fc->entity_id_lims;
        last;
      }
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
  return $self->lims_url() .
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

=item Carp

=item POSIX qw(strftime)

=item LWP::UserAgent

=item HTTP::Request

=item Try::Tiny

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Jennifer Liddle <js10@sanger.ac.uk>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015, 2016, 2017, 2018, 2022, 2025 Genome Research Ltd.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
