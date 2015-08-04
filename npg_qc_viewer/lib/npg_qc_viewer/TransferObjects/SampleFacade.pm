package npg_qc_viewer::TransferObjects::SampleFacade;

use Moose;
use namespace::autoclean;

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc_viewer::TransferObjects::SampleFacade

=head1 SYNOPSIS

=head1 DESCRIPTION

A facade object to show a simplified Sample from model to the view.

=head1 SUBROUTINES/METHODS

=cut

=head2 row

Raw data.

=cut
has 'row'  => (
  is       => 'rw',
  required => 1,
);

=head2 id_sample_lims

Id for sample in ML Data Warehouse

=cut
sub id_sample_lims {
  my $self = shift;
  return $self->row->get_column('id_sample_lims');
}

=head2 name

Name for sample.

=cut
sub name {
  my $self = shift;
  return $self->row->get_column('name') || $self->row->get_column('id_sample_lims');
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

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 Genome Research Ltd.

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
