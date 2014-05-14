#########
# Author:        ajb
# Maintainer:    $Author$
# Created:       2008-06-20
# Last Modified: $Date$
# Id:            $Id$
# Source:        $Source: /repos/cvs/webcore/SHARED_docs/cgi-bin/docrep,v $
# $HeadURL$
#

package npg_qc::model::create_xml;
use strict;
use warnings;
use base qw(npg_qc::model);

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mxs; $r; };

1;
__END__
=head1 NAME

npg_qc::model::create_xml

=head1 VERSION

$Revision$

=head1 SYNOPSIS

  my $oCreateXml = npg_qc::model::create_xml->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::model

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
