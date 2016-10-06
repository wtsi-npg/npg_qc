package npg_qc::autoqc::results::bam_flagstats;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Readonly;
use Carp;

extends qw( npg_qc::autoqc::results::result );
with    qw(
            npg_tracking::glossary::subset
            npg_qc::autoqc::role::bam_flagstats
          );

our $VERSION = '0';

Readonly::Scalar my $HUMAN_SPLIT_ATTR_DEFAULT => 'all';
Readonly::Scalar my $SUBSET_ATTR_DEFAULT      => 'target';

has '+subset' => ( writer      => '_set_subset', );

has 'human_split' => ( isa            => 'Maybe[Str]',
                       is             => 'rw',
                       predicate      => '_has_human_split',
);

has 'library' =>     ( isa  => 'Maybe[Str]',
                       is   => 'rw',
);
has [ qw/ num_total_reads
          unpaired_mapped_reads
          paired_mapped_reads
          unmapped_reads
          unpaired_read_duplicates
          paired_read_duplicates
          read_pair_optical_duplicates
          library_size
          proper_mapped_pair
          mate_mapped_defferent_chr
          mate_mapped_defferent_chr_5
          read_pairs_examined / ] => (
    isa => 'Maybe[Int]',
    is  => 'rw',
);

has 'percent_duplicate' => ( isa => 'Maybe[Num]',
                             is  => 'rw',
);

has 'histogram'         => ( isa     => 'HashRef',
                             is      => 'rw',
                             default => sub { {} },
);

sub BUILD {
  my $self = shift;

  if ($self->_has_human_split && $self->has_subset) {
    if ($self->human_split ne $self->subset) {
      croak sprintf 'human_split and subset attrs are different: %s and %s',
        $self->human_split, $self->subset;
    }
  } else {
    if ($self->_has_human_split) {
      if (!$self->has_subset && $self->human_split ne $HUMAN_SPLIT_ATTR_DEFAULT ) {
        # Backwards compatibility with old results.
        # Will be done by the trigger anyway, but let's not rely on the trigger
        # which we will remove as soon as we can.
        $self->_set_subset($self->human_split);
      }
    } else {
      if ($self->has_subset && $self->subset ne $SUBSET_ATTR_DEFAULT) {
        # Do reverse as well so that the human_split column, while we
        # have it, is correctly populated.
        $self->human_split($self->subset);
      }
    }
  }

  return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

npg_qc::autoqc::results::bam_flagstats

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 id_run

  an optional attribute

=head2 position

  an optional attribute

=head2 tag_index

  an optional attribute

=head2 subset

  an optional subset, see npg_tracking::glossary::subset for details.

=head2 BUILD - ensures human_split and subset fields are populated consistently

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item Readonly

=item Carp

=item npg_tracking::util::types

=item npg_tracking::glossary::subset

=item npg_qc::autoqc::results::result

=item npg_qc::autoqc::role::bam_flagstats

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi E<lt>gq1@sanger.ac.ukE<gt><gt>
Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt><gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 GRL

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
