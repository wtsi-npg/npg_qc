#########
# Author:        Marina Gourtovaia
# Maintainer:    $Author: mg8 $
# Created:       26 October 2011
# Last Modified: $Date: 2011-11-14 10:42:46 +0000 (Mon, 14 Nov 2011) $
# Id:            $Id: tag_metrics.pm 14617 2011-11-14 10:42:46Z mg8 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/autoqc/results/tag_metrics.pm $
#

package npg_qc::autoqc::results::tag_metrics;

use strict;
use warnings;
use Moose;
use Readonly;

extends qw(npg_qc::autoqc::results::result);
with qw(npg_qc::autoqc::role::tag_metrics);

our $VERSION = '0';

has [ qw/ tags
          reads_count
          reads_pf_count
          perfect_matches_count
          perfect_matches_pf_count
          one_mismatch_matches_count
          one_mismatch_matches_pf_count
          matches_percent
          matches_pf_percent /    ] =>  (isa => 'HashRef',
                                         is => 'rw',
                                         default  => sub { return {}; },
                                        );

has [ qw/ spiked_control_index
          max_mismatches_param
          min_mismatch_delta_param
          max_no_calls_param /    ] => (isa => 'Maybe[Int]',
                                        is =>  'rw',
                                       );

has [ qw/ metrics_file
          barcode_tag_name /      ] => (isa => 'Maybe[Str]',
                                        is =>  'rw',
                                       );

no Moose;

1;

__END__


=head1 NAME

 npg_qc::autoqc::results::tag_metrics

=head1 VERSION

 $Revision: 14617 $

=head1 SYNOPSIS

 my $rObj = npg_qc::autoqc::results::tag_metrics->new(id_run => 6551, position => 1, path => q[my_path/6551_1.bam.tag_decode.metrics]);

=head1 DESCRIPTION

 An autoqc result object that wrapps results of barcode decoding
 by picard http://picard.sourceforge.net/command-line-overview.shtml#ExtractIlluminaBarcodes
 according to the metric described in
 http://picard.sourceforge.net/picard-metric-definitions.shtml#ExtractIlluminaBarcodes.BarcodeMetric

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Readonly

=item npg_qc::autoqc::results::result

=item npg_qc::autoqc::role::barcode_metrics

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt><gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 GRL, by Marina Gourtovaia

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
