package npg_qc::Schema::Flators;

use Moose::Role;
use Carp;
use Compress::Zlib;
use MIME::Base64;
use JSON;
use IO::Compress::Xz     qw/ xz   $XzError   /;
use IO::Uncompress::UnXz qw/ unxz $UnXzError /;

our $VERSION = '0';

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::Schema::Flators

=head1 SYNOPSIS

=head1 DESCRIPTION

This Moose role provides custom inflator and deflator functionality for
table classes in the npg_qc::Schema namespace.

=head1 SUBROUTINES/METHODS

=cut

=head2 set_flators4non_scalar

Sets serialization to json for non-scalar values.

  __PACKAGE__->set_flators4non_scalar(@column_names);

The deflator will not work for scalar values since the  set_inflated_columns method
of DBIx::Class::Row intentionally does not deflate scalar values.

=cut

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

=head2 set_flators_wcompression4non_scalar

Sets serialization to json for non-scalar values. The json string
is then compressed and base64 encoded allowing to store the compressed
data in text fields.

  __PACKAGE__->set_flators_wcompression4non_scalar(@column_names);

The deflator will not work for scalar values since the  set_inflated_columns method
of DBIx::Class::Row intensionally does not deflate scalar values.

=cut

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


=head2 set_inflator4xz_compressed_scalar

Sets inflation for scalar xz-compressed data.

  __PACKAGE__->set_inflator4xz_compressed_scalar(@column_names);

There is no deflator since the  set_inflated_columns method
of DBIx::Class::Row intensionally does not deflate scalar values.
See C<compress_xz> as a companion method for deflation.

=cut
sub set_inflator4xz_compressed_scalar {
  my ($package_name, @columns) = @_;

  foreach my $col (@columns) {
    $package_name->inflate_column( $col, {
       inflate => sub {
         my $data = shift;
         my $out;
         if (defined $data) {
           unxz \$data => \$out or croak "unxz failed: $UnXzError\n";
         }
         return $out;
       },
    });
  }
  return;
}

=head2 compress_xz

Returns xz compression of defined attribute or undef.
Can be called as both instance and class level method.

  my $compressed = __PACKAGE__->compress_xz($string_data);
  my $compressed = $self->compress_xz($string_data);

See C<set_inflator4xz_compressed_scalar> as a companion method for
setting the inflator for compressed scalar data.

=cut

sub compress_xz {
  my ($package_name, $data) = @_;
  my $out;
  if (defined $data) {
    xz \$data => \$out or croak "xz failed: $XzError\n";
  }
  return $out;
}

=head2 create_composition_attribute

Adds a lazy-build 'composition' attribute and a build method for it
for tables that have 'iseq_composition' column - an attempt to 
mirror the functionality of the result objects and hide the complexity
of database implementation for composition.

 __PACKAGE__->create_composition_attribute();

=cut

sub create_composition_attribute {
  my $package_name = shift;

  if (!$package_name->result_source_instance()->has_column('id_seq_composition')) {
    croak "Cannot create composition attribute for $package_name";
  }

  my $meta = $package_name->meta();
  $meta->add_attribute(
    'composition' => ( is         => 'ro',
                       isa        => 'npg_tracking::glossary::composition',
                       lazy_build => 1,
                     )
  );
  $meta->add_method(
    '_build_composition' => sub {
      my $self = shift;
      return $self->seq_composition()->create_composition();
    }
  );

  return;
}

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

=item Compress::Zlib

=item MIME::Base64

=item JSON

=item IO::Compress::Xz

=item IO::Uncompress::UnXz

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 GRL

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
