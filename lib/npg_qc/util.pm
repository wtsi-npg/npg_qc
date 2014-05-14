#########
# Author:        Marina Gourtovaia
# Maintainer:    $Author: mg8 $
# Created:       March 2012
# Last Modified: $Date: 2013-08-22 14:28:15 +0100 (Thu, 22 Aug 2013) $
# Id:            $Id: util.pm 17408 2013-08-22 13:28:15Z mg8 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/util.pm $
#
package npg_qc::util;

use strict;
use warnings;
use XML::LibXML;
use base qw(npg::util);

our $VERSION     = do { my ($r) = q$Revision: 17408 $ =~ /(\d+)/mxs; $r; };

sub data_path {
  my $self = shift;
  return $self->SUPER::data_path() . '/npg_qc_web';
}

sub requestor {
  my $uh =  { 'username' => 'public', };
  return $uh;
}

sub parser {
  my $self = shift;
  $self->{parser} ||= XML::LibXML->new();
  return $self->{parser};
}

1;

__END__

=head1 NAME

npg_qc::util - A database handle and utility object

=head1 VERSION

$Revision: 17408 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 data_path - path to data directory containing config.ini and templates sub-directory

  my $sPath - $oUtil->data_path();

=head2 requestor

=head2 parser

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item npg::util

=item base

=item XML::LibXML

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia, E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2012 GRL, by Marina Gourtovaia

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
