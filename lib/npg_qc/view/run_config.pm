#########
# Author:        ajb
# Maintainer:    $Author: jo3 $
# Created:       2008-06-10
# Last Modified: $Date: 2010-03-30 16:40:28 +0100 (Tue, 30 Mar 2010) $
# Id:            $Id: run_config.pm 8943 2010-03-30 15:40:28Z jo3 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/view/run_config.pm $
#

package npg_qc::view::run_config;
use strict;
use warnings;
use base qw(npg_qc::view);
use English qw{-no_match_vars};
use Carp;
use npg_qc::model::run_config;

our $VERSION = '0';

1;
__END__
=head1 NAME

npg_qc::view::run_config

=head1 VERSION

$Revision: 8943 $

=head1 SYNOPSIS

  my $o = npg_qc::view::run_config->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::view

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
