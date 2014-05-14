#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-06-10
# Last Modified: $Date: 2013-08-22 14:28:15 +0100 (Thu, 22 Aug 2013) $
# Id:            $Id: controller.pm 17408 2013-08-22 13:28:15Z mg8 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/controller.pm $
#

package npg_qc::controller;

use strict;
use warnings;
use base qw(npg::controller);

our $VERSION = do { my ($r) = q$Revision: 17408 $ =~ /(\d+)/mxs; $r; };

use npg_qc::model::analysis;
use npg_qc::model::analysis_lane;
use npg_qc::model::analysis_lane_qcal;
use npg_qc::model::create_xml;
use npg_qc::model::cumulative_errors_by_cycle;
use npg_qc::model::error_rate_reference_including_blanks;
use npg_qc::model::error_rate_reference_no_blanks;
use npg_qc::model::error_rate_relative_reference_cycle_nucleotide;
use npg_qc::model::error_rate_relative_sequence_base;
use npg_qc::model::errors_by_cycle;
use npg_qc::model::errors_by_cycle_and_nucleotide;
use npg_qc::model::errors_by_nucleotide;
use npg_qc::model::information_content_by_cycle;
use npg_qc::model::log_likelihood;
use npg_qc::model::main;
use npg_qc::model::most_common_blank_pattern;
use npg_qc::model::most_common_word;
use npg_qc::model::signal_mean;
use npg_qc::model::summary;
use npg_qc::model::run_config;
use npg_qc::model::run_tile;
use npg_qc::model::tile_score;
use npg_qc::model::move_z;
use npg_qc::model::runlog_sax_handler_simple;
use npg_qc::model::run_log;
use npg_qc::model::run_graph;
use npg_qc::model::cache_query;
use npg_qc::model::run;
use npg_qc::model::image_store;
use npg_qc::model::frequency_response_matrix;
use npg_qc::model::offset;
use npg_qc::model::run_recipe;
use npg_qc::model::run_info;

use npg_qc::view::analysis;
use npg_qc::view::create_xml;
use npg_qc::view::cumulative_errors_by_cycle;
use npg_qc::view::error;
use npg_qc::view::errors_by_cycle;
use npg_qc::view::main;
use npg_qc::view::move_z;
use npg_qc::view::run_config;
use npg_qc::view::run_tile;
use npg_qc::view::signal_mean;
use npg_qc::view::summary;
use npg_qc::view::tile_score;
use npg_qc::view::move_z;
use npg_qc::view::run_log;
use npg_qc::view::run_graph;
use npg_qc::view::cache_query;
use npg_qc::view::run;
use npg_qc::view::frequency_response_matrix;
use npg_qc::view::offset;
use npg_qc::view::run_recipe;
use npg_qc::view::run_info;

use npg_qc::util;


1;
__END__

=head1 NAME

npg_qc::controller - npg_qc controller

=head1 VERSION

$Revision: 17408 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

base
strict
warnings
npg::controller
npg_qc::model::create_xml
npg_qc::model::cumulative_errors_by_cycle
npg_qc::model::error_rate_reference_including_blanks
npg_qc::model::error_rate_reference_no_blanks
npg_qc::model::error_rate_relative_reference_cycle_nucleotide
npg_qc::model::error_rate_relative_sequence_base
npg_qc::model::errors_by_cycle
npg_qc::model::errors_by_cycle_and_nucleotide
npg_qc::model::errors_by_nucleotide
npg_qc::model::information_content_by_cycle
npg_qc::model::log_likelihood
npg_qc::model::main
npg_qc::model::most_common_blank_pattern
npg_qc::model::most_common_word
npg_qc::model::signal_mean
npg_qc::model::summary
npg_qc::model::swift_summary
npg_qc::model::run_config
npg_qc::model::run_tile
npg_qc::model::tile_score
npg_qc::model::tile_all
npg_qc::view::create_xml
npg_qc::view::cumulative_errors_by_cycle
npg_qc::view::error
npg_qc::view::errors_by_cycle
npg_qc::view::main
npg_qc::view::run_config
npg_qc::view::run_tile
npg_qc::view::signal_mean
npg_qc::view::summary
npg_qc::view::swift_summary
npg_qc::view::tile_score
npg_qc::util

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown, E<lt>ajb@sanger.ac.ukE<gt> & Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Andy Brown

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
