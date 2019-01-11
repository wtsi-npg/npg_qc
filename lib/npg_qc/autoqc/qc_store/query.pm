package npg_qc::autoqc::qc_store::query;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;

extends 'npg_qc::autoqc::qc_store::query_non_tracking';

our $VERSION = '0';

has 'npg_tracking_schema' => ( isa       => 'npg_tracking::Schema',
                               is        => 'ro',
                               required  => 1,
                             );

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

npg_qc::autoqc::qc_store::query

=head1 SYNOPSIS

=head1 DESCRIPTION

A wrapper object for retrival parameters and options for autoqc results.

=head1 SUBROUTINES/METHODS

=head2 option

Option for loading autoqc results, one of constants defined in npg_qc::autoqc::qc_store::options.

=head2 id_run

=head2 positions

A reference to an array with positions (lane numbers).

=head2 npg_tracking_schema

An instance of npg_tracking::Schema, required.

=head2 db_qcresults_lookup

A boolens flag indicating whether to look for autoqc results in a database.

=head2 BUILD

Called before returning an object to the caller, does some sanity checking.

=head2 to_string

Human friendly description of the object.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

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
