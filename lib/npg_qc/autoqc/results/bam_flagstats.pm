package npg_qc::autoqc::results::bam_flagstats;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;

extends qw( npg_qc::autoqc::results::result );
with    qw(
            npg_tracking::glossary::subset
            npg_qc::autoqc::role::bam_flagstats
          );

our $VERSION = '0';


has [ qw/ library
          target_filter
          target_autosome_filter
        / ] => (
    isa  => 'Maybe[Str]',
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
          read_pairs_examined
          target_length
          target_mapped_reads
          target_proper_pair_mapped_reads
          target_mapped_bases
          target_coverage_threshold
          target_autosome_length
          target_autosome_mapped_reads
          target_autosome_proper_pair_mapped_reads
          target_autosome_mapped_bases
          target_autosome_coverage_threshold
         / ] => (
    isa => 'Maybe[Int]',
    is  => 'rw',
);

has [ qw/ percent_duplicate
          target_percent_gt_coverage_threshold
          target_autosome_percent_gt_coverage_threshold
        / ] => (
    isa => 'Maybe[Num]',
    is  => 'rw',
);

has 'histogram'         => ( isa     => 'HashRef',
                             is      => 'rw',
                             default => sub { {} },
);

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

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

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

Copyright (C) 2017 GRL

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
