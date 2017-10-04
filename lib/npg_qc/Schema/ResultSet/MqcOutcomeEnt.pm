package npg_qc::Schema::ResultSet::MqcOutcomeEnt;

use Moose;
use MooseX::MarkAsMethods autoclean => 1;

extends 'npg_qc::Schema::ResultSet';

our $VERSION = '0';

sub get_rows_with_final_current_outcome {
  my $self = shift;
  return $self->search(
    {'mqc_outcome.short_desc' => {like => '%final'}, 'mqc_outcome.iscurrent' => 1},
    {'join'=>'mqc_outcome'});
}

sub get_ready_to_report {
  my $self = shift;
  my $rs = $self->search({'reported' => undef }, {'prefetch' => 'mqc_outcome'})
                ->search_autoqc({})
                ->search(
                  {},
                  {'order_by' => [qw/seq_component.id_run seq_component.position/]}
                        );
  my @rows = grep { $_->has_final_outcome } $rs->all();
  $rs = $self->result_source->resultset;
  $rs->set_cache(\@rows);
  return $rs;
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
__END__

=head1 NAME

npg_qc::Schema::ResultSet::MqcOutcomeEnt

=head1 SYNOPSIS

=head1 DESCRIPTION

  Extended ResultSet for MqcOutcomeEnt.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 SUBROUTINES/METHODS

=head2 get_rows_with_final_current_outcome

  Returns a list of entities with final outcomes according to business rules.
  Currently it looks into the relationship with the dictionary to find those
  outcomes with a short description ending in 'final'.

=head2 get_ready_to_report

  Returns a resultset representing rows which are ready to be reported,
  ie have a final status but haven't been reported yet.

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::MarkAsMethods

=item npg_qc::Schema::ResultSet

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Jaime Tovar <lt>jmtc@sanger.ac.uk<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 GRL Genome Research Limited

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

