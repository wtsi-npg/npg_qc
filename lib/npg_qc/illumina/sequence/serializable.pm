package npg_qc::illumina::sequence::serializable;

use Moose::Role;
use JSON::XS;
use namespace::autoclean;
use Digest::SHA qw/sha256_hex/;
use Digest::MD5 qw/md5_hex/;
use Carp;

requires 'pack';
requires 'unpack';

our $VERSION = '0';

sub thaw {
  my ( $class, $json, @args ) = @_;
  if (!$json) {
    croak 'JSON string is required';
  }
  return $class->unpack( JSON::XS->new()->decode($json), @args );
}

sub freeze {
  my $self = shift;
  if ( $self->can('sort') ) {
    $self->sort();
  }
  return JSON::XS->new()->canonical(1)->encode( $self->_pack_custom() );
}

sub thaw_from_signature {
  my ( $class, $signature, @args ) = @_;
  if (!$signature) {
    croak 'Object signature is required';
  }
  my %values;
  {
    use warnings FATAL => 'all';
    %values = split /[^[:lower:][:upper:][:digit:]_]/smx, $signature;
  }
  return $class->unpack( \%values, @args );
}

sub freeze_to_signature {
  my $self = shift;
  my $sig = $self->freeze();
  $sig =~ s/\A\{ | \" | \}\Z //gxms;
  return $sig;
}

sub digest {
  my ($self, $digest_type) = @_;
  my $data = $self->freeze();
  return ($digest_type && $digest_type eq 'md5') ?
          md5_hex $data : sha256_hex $data;
}

sub _pack_custom {
  my $self = shift;
  return _clean_pack($self->pack());
}

sub _clean_pack { # Recursive function
  my $old = shift;

  my $type = ref $old;
  if (!$type || $type ne 'HASH') {
    return $old;
  }

  my $values = {};
  while ( my ($k, $v) = each %{$old} ) {
     # Delete __CLASS__ key along with private attrs
    if (defined $v && $k !~ /\A_/) {
      # Treat components the same way
      if (ref $v && ref $v eq 'ARRAY' && $k eq 'components') {
        my @clean = map { _clean_pack($_) } @{$v};
        $v = \@clean;
      }
      $values->{$k} = $v;
    }
  }

  return $values; 
}

no Moose::Role;

1;
__END__

=head1 NAME

npg_qc::illumina::sequence::serialization::component

=head1 SYNOPSIS

=head1 DESCRIPTION

Illumina sequence component serialization.

=head1 SUBROUTINES/METHODS

=head2 thaw

Instantiates an object from a json string.

=head2 freeze

Serializes object's attributes to canonical (ordered) json string.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::Storage

=item namespace::autoclean

=item npg_tracking::glossary::run

=item npg_tracking::glossary::lane

=item npg_tracking::glossary::tag

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL

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
