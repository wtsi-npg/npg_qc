package npg_qc_viewer::Model::MLWarehouseDB;

use Moose;
use namespace::autoclean;
use Carp;

BEGIN { extends 'Catalyst::Model::DBIC::Schema' }

our $VERSION  = '0';

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc_viewer::Model::MLWarehouseDB

=head1 SYNOPSIS

=head1 DESCRIPTION

Catalyst::Model::DBIC::Schema Model using schema WTSI::DNAP::Warehouse::Schema

=head1 SUBROUTINES/METHODS

=cut


__PACKAGE__->config(
    schema_class => 'WTSI::DNAP::Warehouse::Schema',
    connect_info => [], #a fall-back position if connect_info is not defined in the config file
);

=head2 find_library_by_id

TODO

=cut
sub find_library_by_id {
  my ($self, $id_library_lims) = @_;

  if (!defined $id_library_lims) {
    croak q[Id library lims not defined when quering library lims];
  }

  my $where = { 'iseq_flowcell.id_library_lims' => $id_library_lims,
                'me.tag_index' => [ undef, { '!=', 0 }],};

  my $rs = $self->resultset('IseqProductMetric')->
             search($where, {
               join => ['iseq_flowcell'],
               '+columns'  => ['me.id_run',
                               'me.position',
                               'me.tag_index',
                               'iseq_flowcell.id_library_lims',
                               'iseq_flowcell.legacy_library_id',
               ],
               group_by => qw[me.id_run me.position me.tag_index iseq_flowcell.id_library_lims iseq_flowcell.legacy_library_id],
  });

  return $rs;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Catalyst::Model::DBIC::Schema

=item WTSI::DNAP::Warehouse::Schema

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David Jackson

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 Genome Research Ltd.

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
