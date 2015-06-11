package npg_qc::autoqc::results::result_decorated_with_metadata;

use strict;
use warnings;
use Moose;

use npg_qc::autoqc::results::result;

extends qw(npg_qc::autoqc::results::result);

our $VERSION = '0';

has '_decorated_result' => (
  is       => 'ro',
  isa      => 'npg_qc::autoqc::results::result',
  lazy     => 1,
  default => \&build__decorated_result,
  handles  => qr/^(?!get_result_metadata)/,
);

has '_result_metadata' =>  (
  isa        => 'HashRef',
  is         => 'ro',
  reader     => 'get_result_metadata',
);

sub BUILD {
  my $self = shift;
  my $decorated_result = shift;
  my $result_metadata = shift;
  
  $self->_decorated_result = $decorated_result;
  $self->_result_metadata = $result_metadata;
}

no Moose;

1;

