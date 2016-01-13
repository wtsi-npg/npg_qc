package npg_qc_viewer::Util::CompositionFactory;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;

our $VERSION = '0';

has 'rpt_list' => (
     isa           => q[Str],
     is            => q[ro],
     required      => 1,
);

with 'npg_tracking::glossary::composition::factory::rpt' =>
     { 'component_class' =>
       'npg_tracking::glossary::composition::component::illumina' };

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

npg_qc_viewer::Util::CompositionFactory

=head1 SYNOPSIS

  my $factory = npg_qc_viewer::Util::Composition->new(
                  rpt_list => '1:2:3;4:5:6');
  my $composition = $factory->create_composition();

=head1 DESCRIPTION
 
A factory for generating npg_tracking::glossary::composition type objects
from run-position-tag lists. The components in the composition are of the
npg_tracking::glossary::composition::component::illumina type.

=head1 SUBROUTINES/METHODS

=head2 rpt_list

Semi-colon separated list of run:position or run:position:tag strings
that define a composition.

=head2 create_component

See npg_tracking::glossary::composition::factory::rpt.

=head2 create_composition

Creates a npg_tracking::glossary::composition type object that
corresponds to the rpt_list attribute.
See npg_tracking::glossary::composition::factory::rpt.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item npg_tracking::glossary::composition::factory::rpt

=item npg_tracking::glossary::composition::component::illumina

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 Genome Research Limited

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
