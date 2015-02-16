package npg_qc::Schema::ResultSet::MqcOutcomeEnt;

use Moose;
use MooseX::NonMoose;

extends 'DBIx::Class::ResultSet';

our $VERSION = '0';

sub BUILDARGS { $_[2] } # ::RS::new() expects my ($class, $rsrc, $args) = @_

sub get_not_reported {
  my $self = shift;
  $self->search({$self->current_source_alias . '.reported' => undef});
}

sub get_rows_with_final_outcome {
  my $self = shift;
  $self->search({$self->current_source_alias . '.id_mqc_outcome' => [3,4]}); #TODO change final outcome
}

sub get_ready_to_report{
  my $self = shift;
  $self->get_not_reported->get_rows_with_final_outcome;  
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

Extended ResultSet with specific functionality for for manual MQC.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 SUBROUTINES/METHODS

=head2 get_ready_to_report

  Returns a list of MqcOutcomeEnt rows which are ready to be reported (have a final status but haven't been reported yet).

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Moose

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

