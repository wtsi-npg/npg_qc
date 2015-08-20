package npg_qc::illumina::sequence::composition;

use Moose;
use namespace::autoclean;
use MooseX::Storage;
use MooseX::StrictConstructor;
use Carp;
use Readonly;
use List::MoreUtils qw/any/;

with Storage( 'traits' => ['OnlyWhenBuilt'],
              'format' => '=npg_qc::illumina::sequence::serializable' );

our $VERSION = '0';

Readonly::Scalar my $COMPONENT_OBJ_TYPE => q[npg_qc::illumina::sequence::component];

has 'components' => (
      traits    => [ qw/Array/ ],
      is        => 'ro',
      isa       => "ArrayRef[$COMPONENT_OBJ_TYPE]",
      default   => sub { [] },
      handles   => {
          'add_component'     => 'push',
          'has_no_components' => 'is_empty',
          'sort_components'   => 'sort_in_place',
          'find_component'    => 'first',
          'num_components'    => 'count',
                   },
);

before 'add_component' => sub {
  my ($self, @components) = @_;

  if (!@components) {
    croak 'Nothing to add';
  }
  
  my @seen = ();
  foreach my $c ( @components ) {
    _test_attr($c);
    if ( any { !$c->compare_serialized($_) } @seen ) {
      croak sprintf 'Duplicate entry in arguments to add: ', $c->freeze(); 
    }
    if ($self->find($c)) {
      croak sprintf 'Cannot add component %s, already exists', $c->freeze();
    }
    push @seen, $c;
  } 
};

before 'digest' => sub {
  my ($self, @args) = @_;
  if ($self->has_no_components) {
    croak 'Composition is empty, cannot compute digest';
  }
};

before 'freeze' => sub {
  my ($self, @args) = @_;
  $self->sort();
};

sub find {
  my ($self, $c) = @_;
  if ( !defined $c ) {
    croak 'Missing argument';
  }
  _test_attr($c); 
  return $self->find_component( sub { !($c->compare_serialized($_)) } );
}

sub sort {
  my $self = shift;
  $self->sort_components(sub { $_[0]->compare_serialized($_[1]) });
  return;
}

sub _test_attr {
  my $c = shift;
  if ( !(ref $c) || ref $c ne $COMPONENT_OBJ_TYPE ) {
    croak qq[Argument of type $COMPONENT_OBJ_TYPE is expected];
  }
  return;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

npg_qc::illumina::sequence::composition

=head1 SYNOPSIS

=head1 DESCRIPTION

Illumina sequence component definition.

=head1 SUBROUTINES/METHODS

=head2 position

Lane number

=head2 id_run

=head2 tag_index

An optional tag index that uniquely identifies a component
in a multiplexed lane.

=head2 subset

An optional attribute, will default to 'target'.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::Storage

=item namespace::autoclean

=item npg_qc::autoqc::roles::rpt_key

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL

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
