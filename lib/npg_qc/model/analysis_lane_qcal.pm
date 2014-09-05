#########
# Author:        ajb
# Created:       2008-10-06
#

package npg_qc::model::analysis_lane_qcal;
use strict;
use warnings;
use English qw{-no_match_vars};
use Carp;
use base qw(npg_qc::model);

our $VERSION = '0';

__PACKAGE__->mk_accessors(__PACKAGE__->fields());
__PACKAGE__->has_a('npg_qc::model::analysis_lane');

sub fields {
  return qw(
            id_analysis_lane_qcal
            id_analysis_lane
            chastity
            qv
            cum_error
            cum_bases
            cum_perc_error
            cum_perc_total
            error
            bases
            perc_error
            perc_total
            exp_perc_error
          );
}
1;
__END__
=head1 NAME

npg_qc::model::analysis_lane_qcal


=head1 SYNOPSIS

  my $oAnalysisLaneQcal = npg_qc::model::analysis_lane_qcal->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - return array of fields, first of which is the primary key

  my $aFields = $oAnalysisLaneQcal->fields();


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
