#########
# Author:        gq1
# Maintainer:    $Author$
# Created:       2009-09-21
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

package npg_qc::autoqc::results::split_stats;

use strict;
use warnings;
use Moose;
use Carp;
use English qw(-no_match_vars);
use Readonly;

extends qw(npg_qc::autoqc::results::result);
with qw(npg_qc::autoqc::role::split_stats);

our $VERSION    = do { my ($r) = q$Revision$ =~ /(\d+)/smx; $r; };

has '+id_run'     =>  (
                       required   => 0,
		                );

has '+position'   =>  (
                       required   => 0,
		                );

has '+path'       =>  (
                       required   => 0,
		                );

has 'filename1'   =>  (isa        => 'Maybe[Str]',
                       is         => 'rw',
                       required   => 0,
		                );

has 'filename2'   =>  (isa        => 'Maybe[Str]',
                       is         => 'rw',
                       required   => 0,
		                );

has 'ref_name'            =>  (isa            => 'Maybe[Str]',
                               is             => 'rw',
                               required       => 0,
		                         );

has 'reference'           =>  (isa            => 'Maybe[Str]',
                               is             => 'rw',
                               required       => 0,
                              );

has 'num_aligned1'        =>  (isa            => 'Maybe[Int]',
                               is             => 'rw',
                               required       => 0,
		                        );

has 'num_not_aligned1'    =>  (isa            => 'Maybe[Int]',
                               is             => 'rw',
                               required       => 0,
		                        );

has 'alignment_depth1'    =>  (isa            => 'Maybe[HashRef]',
                               is             => 'rw',
                               required       => 0,
		                        );

has 'num_aligned2'        => (isa            => 'Maybe[Int]',
                              is             => 'rw',
                              required       => 0,
		                       );

has 'num_not_aligned2'    => (isa            => 'Maybe[Int]',
                              is             => 'rw',
                              required       => 0,
		                        );

has 'alignment_depth2'    => (isa            => 'Maybe[HashRef]',
                              is             => 'rw',
                              required       => 0,
		                       );


has 'num_aligned_merge'   => (isa            => 'Maybe[Int]',
                              is             => 'rw',
                              required       => 0,
		                       );

has 'num_not_aligned_merge'=>(isa            => 'Maybe[Int]',
                              is             => 'rw',
                              required       => 0,
		                       );

no Moose;

1;
__END__

=head1 NAME

npg_qc::autoqc::results::split_stats

=head1 VERSION

$Revision$

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 id_run

=head2 position

=head2 path

=head2 filename1

=head2 filename2

=head2 ref_name

=head2 reference

=head2 num_aligned1

=head2 num_not_aligned1

=head2 alignment_depth1

=head2 num_aligned2

=head2 num_not_aligned2

=head2 alignment_depth2

=head2 num_aligned_merge

=head2 num_not_aligned_merge

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
Carp
English
Moose
npg_qc::autoqc::results::result

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi, E<lt>gq1@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Guoying Qi

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
