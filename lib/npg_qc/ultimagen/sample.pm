package npg_qc::ultimagen::sample;

use Moose;
use namespace::autoclean;

our $VERSION = '0';

has 'id' => (
  isa      => 'Str',
  is       => 'ro',
  required => 1,
);

has 'index_label' => (
  isa      => 'Str',
  is       => 'ro',
  required => 1,
);

has 'index_sequence' => (
  isa      => 'Str',
  is       => 'ro',
  required => 1,
);

1;