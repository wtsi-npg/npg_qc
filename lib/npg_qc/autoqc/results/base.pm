package npg_qc::autoqc::results::base;

use Moose;
use namespace::autoclean;
use File::Spec::Functions qw( splitpath );
use Carp;

use npg_tracking::glossary::composition;
with qw( npg_qc::autoqc::role::result );
with 'npg_tracking::glossary::composition::factory' =>
  {component_class => 'npg_tracking::glossary::composition::component::illumina'};

our $VERSION = '0';

has 'composition' => (
    is         => 'ro',
    isa        => 'npg_tracking::glossary::composition',
    lazy_build => 1,
    handles   => {
      'composition_digest' => 'digest',
      'num_components'     => 'num_components',
    },
);
sub _build_composition {
  my $self = shift;
  if ($self->is_old_style_result) {
    return $self->create_composition();
  }
  return npg_tracking::glossary::composition->new();
}

sub is_old_style_result {
  my $self = shift;
  return $self->can('id_run') && $self->can('position');
}

sub filename_root {
  my $self = shift;
  return $self->is_old_style_result() ? q[] : $self->composition_digest;
}

sub filename_root_from_filename {
  my ($self, $file_path) = @_;
  my ($volume, $directories, $file) = splitpath($file_path);
  $file =~ s/[.](?:[^.]+)\Z//smx;
  return $file;
}

around 'to_string' => sub {
  my ($orig, $self) = @_;
  return join q[ ], __PACKAGE__ , $self->composition->freeze;
};

around 'equals_byvalue' => sub {
  my ($orig, $self, $other) = @_;

  if (!defined $other) {
    croak 'Nothing to compare to';
  }

  my $other_type = ref $other;
  my $comp;
  if ($other_type) {
    if ($self->is_old_style_result()) {
      $comp =  $self->$orig($other);
    } else {
      if ($other_type eq ref $self->composition) {
        $comp = ($self->composition_digest cmp $other->digest) == 0 ? 1 : 0;
      }
    }
  }

  if (!defined $comp) {
    croak 'Cannot evaluate input ' . $other;
  }

  return $comp;
};

sub execute {
  my $self = shift;
  if ($self->num_components == 0) {
    croak 'Empty composition - cannot run execute()';
  }
  return;
}

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

npg_qc::autoqc::results::base

=head1 SYNOPSIS

=head1 DESCRIPTION

An alternative composition-based parent object for autoqc result objects.

=head1 SUBROUTINES/METHODS

=head2 composition

An npg_tracking::glossary::composition composition objects. If the derived
class inplements id_run and position methods/attributes, a one-component
composition is created automatically. Otherwise an empry composition object
is created.

=head2 is_old_style_result

A method returning true if the derived class implements id_run and position
methods/attributes.

=head2 filename_root

Autoqc result object interface method, see npg_qc::autoqc::role::result for
details. Suggested filename root for serialisation.
For an old-style object as defined by the is_old_style_result method returns an
empty string, otherwise returns a composition digest.

=head2 to_string

Autoqc result object interface method, see npg_qc::autoqc::role::result for
details. Returns a human readable string representation of the object'

=head2 equals_byvalue

Autoqc result object interface method, see npg_qc::autoqc::role::result for details.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item File::Spec::Functions

=item Carp

=item npg_tracking::glossary::composition

=item npg_tracking::glossary::composition::factory

=item npg_tracking::glossary::composition::component::illumina

=item npg_qc::autoqc::role::result

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
