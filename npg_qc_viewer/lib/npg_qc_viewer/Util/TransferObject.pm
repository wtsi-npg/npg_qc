package npg_qc_viewer::Util::TransferObject;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;

with qw/
          npg_tracking::glossary::run
          npg_tracking::glossary::lane
          npg_tracking::glossary::tag
       /;

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

=begin stopwords

deplexing lims rnd gclp flowcell

=end stopwords

=head1 NAME

npg_qc_viewer::Util::TransferObject

=head1 SYNOPSIS

=head1 DESCRIPTION

A transfer object to pass Product Metric data from the model to the view.

=head1 SUBROUTINES/METHODS

=head2 num_cycles

Number of cycles. Usually cycles@iseq_run_lane_metric

=cut
has 'num_cycles'   => (
  isa      => 'Maybe[Int]',
  is       => 'rw',
  required => 0,
);

=head2 time_comp

When run was complete

=cut
has 'time_comp'    => (
  isa      => 'Maybe[DateTime]',
  is       => 'rw',
  required => 0,
);

=head2 tag_sequence

Tag sequence for deplexing

=cut
has 'tag_sequence' => (
  isa      => 'Maybe[Str]',
  is       => 'rw',
  required => 0,
);

=head2 study_name

Name study lims

=cut
has 'study_name'     => (
  isa      => 'Maybe[Str]',
  is       => 'rw',
  required => 0,
);

=head2 id_sample_lims

Id of sample lims

=cut
has 'id_sample_lims' => (
  isa      => 'Maybe[Str]',
  is       => 'rw',
  required => 0,
);

=head2 sample_name

Name of sample lims

=cut
has 'sample_name' => (
  isa      => 'Maybe[Str]',
  is       => 'rw',
  required => 0,
);

=head2 supplier_sample_name

Supplier sample name

=cut
has 'supplier_sample_name' => (
  isa      => 'Maybe[Str]',
  is       => 'rw',
  required => 0,
);

=head2 id_library_lims

Id of library lims

=cut
has 'id_library_lims' => (
  isa      => 'Maybe[Str]',
  is       => 'rw',
  required => 0,
);

=head2 legacy_library_id

Legacy library id lims

=cut
has 'legacy_library_id' => (
  isa      => 'Maybe[Str]',
  is       => 'rw',
  required => 0,
);

=head2 id_pool_lims

Id pool lims

=cut
has 'id_pool_lims' => (
  isa      => 'Maybe[Str]',
  is       => 'rw',
  required => 0,
);

=head2 rnd

Flag for R&D runs

=cut
has 'rnd' => (
  is       => 'rw',
  required => 0,
);

=head2 is_gclp

Flag for gclp flowcell

=cut
has 'is_gclp' => (
  isa      => 'Bool',
  is       => 'rw',
  required => 0,
  default  => 0,
);

=head2 entity_id_lims

Id for entity lims

=cut
has 'entity_id_lims' => (
  isa      => 'Maybe[Str]',
  is       => 'rw',
  required => 0,
);

=head2 reset_as_pool

Resets object's attributes as fits for a pool

=cut
sub reset_as_pool {
  my $self = shift;
  for my $attr (qw/tag_sequence
                   study_name
                   id_sample_lims
                   sample_name
                   supplier_sample_name/) {
    $self->$attr(undef);
  }
  $self->id_library_lims($self->id_pool_lims);
  return;
}

=head2 provenance

Returns a list containing library id and, optionally, sample and study names

=cut
sub provenance {
  my $self = shift;
  my @p = grep { $_ } ($self->id_library_lims, $self->sample_name, $self->study_name);
  return @p;
}

=head2 sample_name4display

Sometimes users prefer supplier_sample_name to sample_name.
Returns supplier_sample_name, falls back to sample_name.

=cut
sub sample_name4display {
  my $self = shift;
  return $self->supplier_sample_name || $self->sample_name;
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

=item npg_tracking::glossary::run

=item npg_tracking::glossary::lane

=item npg_tracking::glossary::tag

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Jaime Tovar Corona E<lt>jmtc@sanger.ac.ukE<gt>

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
