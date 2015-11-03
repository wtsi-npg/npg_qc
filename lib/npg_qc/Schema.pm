
package npg_qc::Schema;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use Moose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces(
    default_resultset_class => 'ResultSet',
);


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2015-10-23 16:29:56
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1VnoZJVlyZFagZssn5EKNg

use namespace::autoclean;
our $VERSION = '0';
with qw/npg_tracking::util::db_connect/;

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
__END__

=head1 NAME

npg_qc::Schema

=head1 SYNOPSIS

=head1 DESCRIPTION

A Moose class for a DBIx schema with an ability to retrieve db cridentials
from a configuration file. Provides a schema object for a DBIx binding
for the npgqc database. Instructs to use a custom class npg_qc::Schema::ResultSet
to derive ResultSet objects from.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::MarkAsMethods

=item DBIx::Class::Schema

=item namespace::autoclean;

=item npg_tracking::util::db_connect

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL

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

