#########
# Author:        Marina Gourtovaia
# Maintainer:    $Author: mg8 $
# Created:       14 April 2009
# Last Modified: $Date: 2013-01-10 14:09:35 +0000 (Thu, 10 Jan 2013) $
# Id:            $Id: insert_size.pm 16446 2013-01-10 14:09:35Z mg8 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/autoqc/results/insert_size.pm $
#

package npg_qc::autoqc::results::insert_size;

use strict;
use warnings;
use Moose;
use Carp;
use English qw(-no_match_vars);
use Readonly;
use Math::Round qw(round);

use npg_common::diagram::visio_histo_google;
use npg_tracking::util::types;

extends qw( npg_qc::autoqc::results::result );
with    qw( npg_qc::autoqc::role::insert_size );

our $VERSION    = do { my ($r) = q$Revision: 16446 $ =~ /(\d+)/smx; $r; };
## no critic (Documentation::RequirePodAtEnd)


=head1 NAME

npg_qc::autoqc::results::insert_size

=head1 VERSION

$Revision: 16446 $

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=cut


=head2 filenames

A list that contains names of the files that were used by the check. Read-only.

=cut
has 'filenames'    => (isa        => 'ArrayRef',
                       is         => 'rw',
                       required   => 0,
		      );


=head2 bins

Bin array for insert sizes for all reads

=cut
has 'bins'         => (isa             => 'Maybe[ArrayRef]',
                       is              => 'rw',
                       required        => 0,
                      );

=head2 bin_width

Bin width

=cut
has 'bin_width'    => (isa             => 'Maybe[NpgTrackingNonNegativeInt]',
                       is              => 'rw',
                       required        => 0,
                      );


=head2 min_isize

The lowest insert size

=cut
has 'min_isize'    => (isa             => 'Maybe[NpgTrackingNonNegativeInt]',
                       is              => 'rw',
                       required        => 0,
                      );


=head2 expected_mean

Expected mean for backward compatibility

=cut
has 'expected_mean'  =>  (isa             => 'Maybe[NpgTrackingNonNegativeInt]',
                          is              => 'rw',
                          required        => 0,
                         );

=head2 expected_size

Expected size range

=cut
has 'expected_size'  =>  (isa             => 'Maybe[ArrayRef]',
                          is              => 'rw',
                          required        => 0,
                         );


=head2 mean

Mean

=cut
has 'mean'      =>       (isa             => 'Maybe[NpgTrackingNonNegativeInt]',
                          is              => 'rw',
                          required        => 0,
                         );

=head2 std

Std

=cut
has 'std'      =>       (isa             => 'Maybe[NpgTrackingNonNegativeInt]',
                         is              => 'rw',
                         required        => 0,
                        );


=head2 quartile1

First quartile

=cut
has 'quartile1'  =>      (isa             => 'Maybe[NpgTrackingNonNegativeInt]',
                          is              => 'rw',
                          required        => 0,
                         );

=head2 quartile3

Third quartile

=cut
has 'quartile3'  =>      (isa             => 'Maybe[NpgTrackingNonNegativeInt]',
                          is              => 'rw',
                          required        => 0,
                         );

=head2 median

Median (second quartile)

=cut
has 'median'      =>     (isa             => 'Maybe[NpgTrackingNonNegativeInt]',
                          is              => 'rw',
                          required        => 0,
                         );


=head2 sample_size

Number of reads that were attempted to align

=cut
has 'sample_size'       =>     (isa             => 'Maybe[NpgTrackingNonNegativeInt]',
                                is              => 'rw',
                                required        => 0,
                               );

=head2 paired_reads_direction_in

True if the direction of the majority of properly paired reads in, false otherwise

=cut
has 'paired_reads_direction_in'  => (isa             => 'Bool',
                                     is              => 'rw',
                                     required        => 0,
                                     default         => 1,
			            );

=head2 num_well_aligned_reads

Number of properly paired read pairs in the majority direction

=cut
has 'num_well_aligned_reads'  => (isa             => 'Maybe[NpgTrackingNonNegativeInt]',
                                  is              => 'rw',
                                  required        => 0,
			         );

=head2 num_well_aligned_reads_opp_dir

Number of properly paired read pairs in opposite to the majority direction

=cut
has 'num_well_aligned_reads_opp_dir'  => (isa             => 'Maybe[NpgTrackingNonNegativeInt]',
                                          is              => 'rw',
                                          required        => 0,
			                 );



=head2 reference

A path to the binary version of the reference that was used in the aligning

=cut
has 'reference' => (isa      => 'Maybe[Str]',
                    is       => 'rw',
                    required => 0,
		   );

no Moose;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item English

=item Readonly

=item Math::Round

=item npg_common::diagram::visio_histo_google

=item npg_tracking::util::types

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Marina Gourtovaia

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
