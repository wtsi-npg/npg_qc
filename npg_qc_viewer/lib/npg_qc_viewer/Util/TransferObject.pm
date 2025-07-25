package npg_qc_viewer::Util::TransferObject;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Carp;

with qw/
          npg_tracking::glossary::run
          npg_tracking::glossary::lane
          npg_tracking::glossary::tag
       /;

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

=begin stopwords

deplexing lims rnd metadata flowcell

=end stopwords

=head1 NAME

npg_qc_viewer::Util::TransferObject

=head1 SYNOPSIS

=head1 DESCRIPTION

A wrapper object for LIMs and run metadata about an entity
(individual library or a pool)

=head1 SUBROUTINES/METHODS

=head2 num_cycles

Number of cycles in a run

=cut
has 'num_cycles'   => (
  isa      => 'Maybe[Int]',
  is       => 'ro',
  required => 0,
);

=head2 time_comp

Date and time when run was complete

=cut
has 'time_comp'    => (
  isa      => 'Maybe[DateTime]',
  is       => 'ro',
  required => 0,
);

=head2 tag_sequence

Tag sequence used for deplexing

=cut
has 'tag_sequence' => (
  isa      => 'Maybe[Str]',
  is       => 'ro',
  required => 0,
);

=head2 study_name

Study name

=cut
has 'study_name'     => (
  isa      => 'Maybe[Str]',
  is       => 'ro',
  required => 0,
);

=head2 sample_id

Sample identifier

=cut
has 'sample_id' => (
  isa      => 'Maybe[Str]',
  is       => 'ro',
  required => 0,
);

=head2 sample_name

Sample name

=cut
has 'sample_name' => (
  isa      => 'Maybe[Str]',
  is       => 'ro',
  required => 0,
);

=head2 sample_supplier_name

Supplier sample name

=cut
has 'sample_supplier_name' => (
  isa      => 'Maybe[Str]',
  is       => 'ro',
  required => 0,
);

=head2 id_library_lims

Library identifier

=cut
has 'id_library_lims' => (
  isa      => 'Maybe[Str]',
  is       => 'rw',
  required => 0,
);

=head2 legacy_library_id

Legacy library identifier

=cut
has 'legacy_library_id' => (
  isa      => 'Maybe[Str]',
  is       => 'rw',
  required => 0,
);

=head2 rnd

Flag for R&D runs

=cut
has 'rnd' => (
  is       => 'ro',
  required => 0,
);

=head2 is_control

Flag for control/'spiked in' entity from flowcell

=cut
has 'is_control' => (
  isa      => 'Bool',
  is       => 'ro',
  required => 0,
);

=head2 is_pool

Flag for a pooled lane

=cut
has 'is_pool' => (
  isa      => 'Bool',
  is       => 'ro',
  required => 0,
);

=head2 entity_id_lims

LIMs identifier for this entity

=cut
has 'entity_id_lims' => (
  isa      => 'Maybe[Str]',
  is       => 'ro',
  required => 0,
);

=head2 instance_qc_able

Boolean attribute, true if the entity is subject to manual QC,
false otherwise.

=cut
has 'instance_qc_able' => (
  isa        => 'Bool',
  is         => 'ro',
  required   => 0,
);

=head2 provenance

Returns a list containing library id and, optionally, sample and study names

=cut
sub provenance {
  my $self = shift;
  return (grep { $_ } ($self->id_library_lims, $self->sample_name, $self->study_name));
}

=head2 sample_name4display

Sometimes users prefer supplier_sample_name to sample_name.
Returns supplier_sample_name, falls back to sample_name.

=cut
sub sample_name4display {
  my $self = shift;
  return $self->sample_supplier_name || $self->sample_name;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item Carp

=item npg_tracking::glossary::run

=item npg_tracking::glossary::lane

=item npg_tracking::glossary::tag

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Jaime Tovar Corona E<lt>jmtc@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017, 2025 Genome Research Ltd.

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
