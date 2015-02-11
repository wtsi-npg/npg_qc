package npg_qc_viewer::Model::WarehouseDB;

use Moose;
use Carp;
use Readonly;

BEGIN { extends 'Catalyst::Model::DBIC::Schema' }

our $VERSION  = '0';
## no critic (Documentation::RequirePodAtEnd ProhibitNoisyQuotes)

Readonly::Scalar our $LESS => -1;
Readonly::Scalar our $MORE =>  1;
Readonly::Scalar our $SAME =>  0;
Readonly::Scalar our $SAMPLE_TUBE_ASSET_TYPE => q[SampleTube];

=head1 NAME

npg_qc_viewer::Model::WarehouseDB

=head1 SYNOPSIS

=head1 DESCRIPTION

Catalyst::Model::DBIC::Schema Model using schema npg_warehouse::Schema

=head1 SUBROUTINES/METHODS

=cut


__PACKAGE__->config(
    schema_class => 'npg_warehouse::Schema',
    connect_info => [], #a fall-back position if connect_info is not defined in the config file
);

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Readonly

=item Catalyst::Model::DBIC::Schema

=item npg_warehouse::Schema

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David Jackson

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Genome Research Ltd.

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


