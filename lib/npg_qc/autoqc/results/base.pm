package npg_qc::autoqc::results::base;

use Moose;
use namespace::autoclean;
use Carp;
use Readonly;

use npg_qc::illumina::sequence::component;
use npg_qc::illumina::sequence::composition;

with qw( npg_qc::autoqc::role::result );

our $VERSION = '0';

Readonly::Scalar my $COMPOSITION_PACKAGE => 'npg_qc::illumina::sequence::composition';

has 'composition' => (
    is         => 'ro',
    isa        => $COMPOSITION_PACKAGE,
    lazy_build => 1,
    handles   => {
      'composition_digest' => 'digest',
    }
);
sub _build_composition {
  my $self = shift;
  my $composition = $COMPOSITION_PACKAGE->new();
  if ($self->is_old_style_result()) {
    my $c = npg_qc::illumina::sequence::component->new(
      id_run    => $self->id_run,
      position  => $self->position,
      tag_index => $self->can('tag_index') && defined $self->tag_index
                 ? $self->tag_index : undef,
      subset    => $self->can('subset') && defined $self->subset
                 ? $self->subset : undef,
    );
    $composition->add_component($c);
  }
  return $composition;
}

sub is_old_style_result {
  my $self = shift;
  return $self->can('id_run') && $self->can('position');
}

sub filename_root {
  my $self = shift;
  return $self->is_old_style_result() ? q[] : $self->composition_digest;
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
      if ($other_type eq $COMPOSITION_PACKAGE) {
        $comp = ($self->composition_digest cmp $other->digest) == 0 ? 1 : 0;
      }
    }
  }

  if (!defined $comp) {
    croak 'Cannot evaluate input ' . $other;
  }

  return $comp;
};

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

npg_qc::autoqc::results::result

=head1 SYNOPSIS

=head1 DESCRIPTION

A base class to wrap the result of autoqc.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item npg_tracking::util::types

=item npg_tracking::glossary::run

=item npg_tracking::glossary::lane

=item npg_tracking::glossary::tag

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
