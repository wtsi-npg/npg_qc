package npg_qc::report::genotype_call;

use Moose;
use namespace::autoclean;
use REST::Client;
use Readonly;
use DateTime;
use DateTime::TimeZone;
use st::api::base;
use Try::Tiny;
use JSON;
use Carp;


with 'npg_qc::report::common';

our $VERSION = '0';

Readonly::Scalar my $POST_SUCCESS_CODE => 201;
Readonly::Scalar my $HTTP_TIMEOUT      => 180;
Readonly::Scalar my $MAX_ERRORS        => 5;


has 'api_url' => (
  isa           => 'Str',
  is            => 'ro',
  lazy          => 1,
  builder       => '_build_api_url',
  documentation => 'Optionally provide url for api endpoint.',);

sub _build_api_url {
  my $self = shift;
  return st::api::base->lims_url() . q[/api/v2/qc_results];
}

has 'max_errors' => (
  isa           => 'Int',
  is            => 'ro',
  default       => $MAX_ERRORS,
  documentation => 'Optionally specify the max number of errors before giving up.',);


has '_error_count' => (
  isa           => 'Int',
  is            => 'rw',
  default       => 0,
  init_arg      => undef,
  documentation => 'The number of errors generated while posting.',);


has '_client'  => (
  isa           => 'REST::Client',
  is            => 'ro',
  lazy          => 1,
  builder       => '_build_client',
  init_arg      => undef,
  documentation => 'Client to post results to LIMs.',);

sub _build_client {
  my $self = shift;

  my $client = REST::Client->new();
  $client->setHost($self->api_url);
  $client->setTimeout($HTTP_TIMEOUT);
  $client->addHeader('Content-Type', 'application/vnd.api+json');
  return $client;
}

has '_data4reporting' => (
  isa           => 'ArrayRef[HashRef]',
  is            => 'ro',
  lazy          => 1,
  builder       => '_build_data4reporting',
  init_arg      => undef,
  documentation => 'Previously unreported genotype call results.',);

sub _build_data4reporting {
  my $self = shift;

  my $product_rs = $self->mlwh_schema->resultset('IseqProductMetric');

  my $rs = $self->qc_schema->resultset('GenotypeCall')->search
    ({'me.reported' => undef, 'me.pass' => { q[!=] , undef }});

  my $data = [];

  while (my $result = $rs->next()) {
    my $num_components = $result->composition->num_components();
    if ($num_components > 1) {
         croak q[Too many components for composition ],
         $result->id_seq_composition, q[ - only expect one];
    }

    my $component = $result->composition->get_component(0);

    if (defined $component->subset) {
      croak q[Error attempting to report subset composition ],
         $result->id_seq_composition;
    }

    my $sample_uuid;
    try{
      my $sample = $product_rs->search
        ({
          'me.id_run'    => $component->id_run,
          'me.position'  => $component->position,
          'me.tag_index' => $component->tag_index,
         },
         {
          'prefetch' => {'iseq_flowcell' => 'sample'},
         })->first->iseq_flowcell->sample;
      $sample_uuid = $sample->uuid_sample_lims;
    } catch {
      croak q[Sample information not found for run ], $component->id_run,
        q[ pos ], $component->position, q[ tag ], $component->tag_index;
    };

    push @{$data},  {
      'sample_uuid' => $sample_uuid,
      'row'         => $result,
    };
  }

  return $data;
}



sub load {
  my $self = shift;

  my $data = $self->_data4reporting();

  foreach my $d (@{$data}) {
    sleep 1; # To help LIMs server

    if ($self->_error_count >= $self->max_errors) {
      $self->_log(q(Aborting as errors have exceeded the maximum allowed));
      last;
    }

    my $reported = $self->_report($self->_construct_data($d));

    if ($reported && !$self->dry_run) {
      my $result = $d->{'row'};
      $result->update_reported($self->_time_now);
    }

  }
  return;
}

sub _construct_data {
  my ($self,$data) = @_;

  my $formatted = {};
  push @{$formatted->{'data'}->{'attributes'}},
  {'uuid'  => $data->{'sample_uuid'},
   'key'   => 'primer_panel',
   'value' => $data->{'row'}->gbs_plex_name,
   'units' => 'panels'};
  push @{$formatted->{'data'}->{'attributes'}},
  {'uuid'  => $data->{'sample_uuid'},
   'key'   => 'loci_tested',
   'value' => $data->{'row'}->genotypes_attempted,
   'units' => 'bases'};
  push @{$formatted->{'data'}->{'attributes'}},
  {'uuid'  => $data->{'sample_uuid'},
   'key'   => 'loci_passed',
   'value' => $data->{'row'}->genotypes_passed,
   'units' => 'bases'};
  if($data->{'row'}->sex){
    push @{$formatted->{'data'}->{'attributes'}},
    {'uuid'  => $data->{'sample_uuid'},
     'key'   => 'gender_markers',
     'value' => $data->{'row'}->sex,
     'units' => 'codes'};
  }

  return encode_json($formatted);
}

sub _report {
  my ($self,$json) = @_;

  if ($self->verbose) {
    $self->_log(qq(Sending $json to ). $self->api_url);
  }

  my $success;
  if (!$self->dry_run) {
    my $client   = $self->_client()->POST(q[/], $json);

    my $response = $client->responseCode();
    $success = ($response == $POST_SUCCESS_CODE) ? 1 : 0;
    if (!$success) {
      $self->_log(qq(Response code $response : posting $json failed));
      $self->_error_count( $self->_error_count + 1 );
    }
  }
  return $success;
}

sub _log {
  my ($self, $txt) = @_;
  my $m = $self->_time_now . ": $txt";
  if ($self->dry_run) {
    $m = 'DRY RUN: ' . $m;
  }
  warn "$m\n";
  return;
}

sub _time_now {
  return DateTime->now(time_zone => DateTime::TimeZone->new(name => q[local]));
}


__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

npg_qc::report::genotype_call

=head1 SYNOPSIS

 npg_qc::report::genotype_call->new()->load();

=head1 DESCRIPTION

  Reporter for genotype_call results. The plex-level results are posted to a 
  LIMs URL. Multiple results can be posted for the same sample which takes account 
  of the fact that a sample could be run on different primer panels or re-run with 
  the same panel on a different run. However it also means that if a duplicate result 
  were to be reported it would also be entered into the LIMs successfully but with 
  a more recent date.

=head1 SUBROUTINES/METHODS

=head2 api_url

  Optionally provide an api endpoint otherwise the default will be used.

=head2 max_errors

  Optionally define the maximum post errors before we give up trying, otherwise 
  the default maximum will be used.

=head2 load
  
  Retrieves all unreported plex-level genotype_call results and tries to post 
  them to the LIMs qc results API. No account is currently taken of manual QC 
  result for a plex, even if present. If a post is successful, genotype_call 
  results are recorded as reported by setting a timestamp in the qc table. 
  Unsuccessfull attempts are logged until a maximum number of failures is reached.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item REST::Client

=item Readonly

=item DateTime

=item DateTime::TimeZone

=item st::api::base

=item Try::Tiny

=item JSON

=item Carp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 GRL

This file is part of NPG.

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
