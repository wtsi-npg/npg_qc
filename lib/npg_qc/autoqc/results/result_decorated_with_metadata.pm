package npg_qc::autoqc::results::result_decorated_with_metadata;

use strict;
use warnings;
use Moose;

use npg_qc::autoqc::results::result;

extends qw(npg_qc::autoqc::results::result);

our $VERSION = '0';

has 'decorated_result' => (
  is       => 'ro',
  isa      => 'npg_qc::autoqc::results::result',
  required => 1,
  handles  => qr/^(?!get_origin)/,
);

has 'metadata'   =>  (
  isa        => 'HashRef',
  is         => 'ro',
  required   => 1,
);

sub BUILD {
  my $self = shift;
  my $decorated_result = shift;
  my $metadata = shift;
  
  $self->decorated_result = $decorated_result;
  $self->metadata = $metadata;
}

sub get_metadata {
  my $self = shift;
  return $self->metadata;
}

no Moose;

1;

