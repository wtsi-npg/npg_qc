#########
# Author:        Marina Gourtovaia
# Created:       February 2014
#

package npg_qc::Schema::Flators;

use strict;
use warnings;
use Carp;
use Compress::Zlib;
use MIME::Base64;
use JSON;
use Moose::Role;

our $VERSION = do { my ($r) = q$LastChangedRevision$ =~ /(\d+)/mxs; $r; };

sub set_flators4non_scalar {
  my ($package_name, @columns) = @_;
  foreach my $col (@columns) {
    $package_name->add_columns(
      q[+].$col,
      { serializer_class => q[JSON] },
    );
  }
  return;
}

sub set_flators_wcompression4non_scalar {
  my ($package_name, @columns) = @_;
  foreach my $col (@columns) {
    $package_name->inflate_column( $col, {
       inflate => sub {
         my $data = shift;
         my $result;
         if (defined $data) {
           eval {
             $result = from_json($data);
             1;
           } or do {
             $result = from_json(uncompress(decode_base64($data)));
           };
         }
         return $result;
       },
       deflate => sub {
         my $data = shift;
         defined $data ? encode_base64(compress(to_json($data)), q[]) : $data;
       },
    });
  }
  return;
}

sub set_inflator4scalar {
  my ($package_name, $col_name, $is_string) = @_;
  my $db_default = $package_name->result_source_instance->column_info($col_name)->{'default_value'};
  $package_name->inflate_column($col_name, {
    inflate => sub {
      my $db_value = shift;
      if ($is_string) {
        $db_value eq $db_default ? undef : $db_value;
      } else {
        $db_value == $db_default ? undef : $db_value;
      }
    },
  });
  return;
}

sub deflate_unique_key_components {
  my ($package_name, $values) = @_;
  if (!defined $values) {
    croak q[Values hash should be defined];
  }
  if (ref $values ne q[HASH]) {
    croak q[Values shoudl be a hash];
  }
  my $source = $package_name->result_source_instance();
  my %constraints = $source->unique_constraints();
  my @names = grep {$_ ne 'primary'} keys %constraints;
  if (scalar @names > 1) {
    croak qq[Multiple unique constraints in $package_name];
  }
  foreach my $col_name (@{$constraints{$names[0]}}) {
    if (!defined $values->{$col_name} && defined $source->column_info($col_name)->{'default_value'}) {
      $values->{$col_name} = $source->column_info($col_name)->{'default_value'};
    }
  }

  ################
  #
  # Temporary measure to push existing data through
  #
  ##no critic (ProhibitMagicNumbers)
  if  ($package_name eq 'npg_qc::Schema::Result::BamFlagstats' &&
      $values->{'library_size'} && $values->{'library_size'} == -1) {
    $values->{'library_size'} = undef;
  }
  ##use critic
  return;
}

1;

__END__

=head1 NAME

npg_qc::Schema::Flators

=head1 VERSION

$LastChangedRevision$

=head1 SYNOPSIS

=head1 DESCRIPTION

This Moose role provides custom inflator and deflator functionality for
table classes in teh npg_qc::Schema namespace. 

=head1 SUBROUTINES/METHODS

=head2 set_flators4non_scalar - sets serialization to json for non-scalar values.
  Should be used from a table class in the following way:

  __PACKAGE__->set_flators4non_scalar(@column_names);

=head2 set_flators_wcompression4non_scalar - sets serialization to json for non-scalar values.
  Should be used from a table class in the following way:

  __PACKAGE__->set_flators_wcompression4non_scalar(@column_names);

=head2 set_inflator4scalar - sets inflation/deflation for scalar values for
  columns that have defaults and non0null constrain set.
  Should be used from a table class in the following way:

  __PACKAGE__->set_inflator4scalar($column_name, [$is_string]);

  Second attribute is boolean indicating whether the value is a string; it is optional.
  
=head2 deflate_unique_key_components - takes a hash key reference of column names and
  column values, deflates unique key components if needed, ensuring that if this hash reference
  is used for querying, correct results will be produced.
  Should be used from a table class in the following way:

  __PACKAGE__->deflate_unique_key_components($values);

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Carp

=item Compress::Zlib

=item MIME::Base64

=item JSON

=item Moose::Role

=item MooseX::MarkAsMethods

=item DBIx::Class::Schema

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 GRL, Marina Gourtovaia

This program is free software: you can redistribute it and/or modify
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
