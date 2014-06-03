#########
# Author:        ajb
# Created:       2008-11-06
#

package npg_qc::view::run;
use strict;
use warnings;
use base qw(npg_qc::view::summary);


our $VERSION = '0';

1;
__END__
=head1 NAME

npg_qc::view::run

=head1 SYNOPSIS

  my $oRun = npg_qc::view::run->new({util => $util});

=head1 DESCRIPTION

Base model to sit under npg_qc::view::summary

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::view::summary
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
