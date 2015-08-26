package npg_qc::Schema::ResultSet::MqcLibraryOutcomeEnt;

use Moose;
use namespace::autoclean;
use MooseX::NonMoose;

extends 'DBIx::Class::ResultSet';

our $VERSION = '0';

sub BUILDARGS {
  my ($class, $rsrc, $args) = @_;
  return $args;
} # ::RS::new() expects my ($class, $rsrc, $args) = @_

sub get_outcomes_as_hash{
  my ($self, $id_run, $position) = @_;
  #TODO validate params

  #Loading previuos status qc for tracking and mqc.
  my $previous_mqc = {};
  my $previous_rs = $self->search({'id_run'=>$id_run, 'position'=>$position});
  while (my $obj = $previous_rs->next) {
    $previous_mqc->{$obj->tag_index} = $obj->mqc_outcome->short_desc;
  }
  return $previous_mqc;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

npg_qc::Schema::ResultSet::MqcLibraryOutcomeEnt

=head1 SYNOPSIS

=head1 DESCRIPTION

Extended ResultSet with specific functionality for for manual MQC.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 SUBROUTINES/METHODS

=head2 BUILDARGS

  Calling parent constructor.

=head2 get_outcomes_as_hash

  Returns a hash of plex=>outcome for those plexes in the database for the id_run/position specified.

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Moose

=item namespace::autoclean

=item MooseX::NonMoose

=item DBIx::Class::ResultSet

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Jaime Tovar <lt>jmtc@sanger.ac.uk<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL Genome Research Limited

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

