#########
# Author:        ajb
# Maintainer:    $Author: jo3 $
# Created:       2008-10-06
# Last Modified: $Date: 2010-03-30 16:40:28 +0100 (Tue, 30 Mar 2010) $
# Id:            $Id: analysis_lane.pm 8943 2010-03-30 15:40:28Z jo3 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/model/analysis_lane.pm $
#

package npg_qc::model::analysis_lane;
use strict;
use warnings;
use English qw{-no_match_vars};
use Carp;
use base qw(npg_qc::model);

our $VERSION = '0';

__PACKAGE__->mk_accessors(__PACKAGE__->fields());
__PACKAGE__->has_a('npg_qc::model::analysis');
__PACKAGE__->has_many('npg_qc::model::analysis_lane_qcal');

sub fields {
  return qw(id_analysis_lane
            id_analysis
            id_run
            position
            tile_count
            align_score_pf
            align_score_pf_err
            clusters_pf
            clusters_pf_err
            clusters_raw
            clusters_raw_err
            clusters_tilemean_raw
            cycle1_int_pf
            cycle1_int_pf_err
            cycle20_perc_int
            cycle20_perc_int_err
            cycle_10_20_av_perc_loss_pf
            cycle_10_20_av_perc_loss_pf_err
            cycle_2_10_av_perc_loss_pf
            cycle_2_10_av_perc_loss_pf_err
            cycle_2_4_av_int_pf
            cycle_2_4_av_int_pf_err
            equiv_perfect_clusters_pf
            equiv_perfect_clusters_raw
            error_rate_pf
            error_rate_pf_err
            lane_yield
            perc_align_pf
            perc_align_pf2
            perc_align_pf_err
            perc_clusters_pf
            perc_clusters_pf_err
            perc_error_rate_pf
            perc_error_rate_raw
            perc_phasing
            perc_prephasing
            perc_retained);
}

1;
__END__
=head1 NAME

npg_qc::model::analysis_lane


=head1 VERSION

$Revision: 8943 $

=head1 SYNOPSIS

  my $oAnalysisLane = npg_qc::model::analysis_lane->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - return array of fields, first of which is the primary key

  my $aFields = $oAnalysisLane->fields();


=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::model
English
Carp

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown, E<lt>ajb@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Andy Brown

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
