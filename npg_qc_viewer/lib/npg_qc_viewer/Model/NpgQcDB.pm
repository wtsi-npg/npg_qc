package npg_qc_viewer::Model::NpgQcDB;

use Moose;
use namespace::autoclean;
use Carp;

BEGIN { extends 'Catalyst::Model::DBIC::Schema' }

our $VERSION  = '0';

__PACKAGE__->config(
  schema_class => 'npg_qc::Schema',
  connect_info => [], #a fall-back position if connect_info is not defined in the config file
);

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

npg_qc_viewer::Model::NpgQcDB

=head1 SYNOPSIS  

=head1 DESCRIPTION

A model for the NPG QC database DBIx schema

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Catalyst::Model::DBIC::Schema

=item npg_qc::Schema

=item Carp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 Genome Research Ltd.

This file is part of NPG software.

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

