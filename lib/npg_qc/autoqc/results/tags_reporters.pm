#sh########
# Author:        Kevin Lewis
# Created:       12 August 2013
#

package npg_qc::autoqc::results::tags_reporters;

use strict;
use warnings;
use Moose;
use Readonly;

extends qw(npg_qc::autoqc::results::result);
with qw(npg_qc::autoqc::role::tags_reporters);

our $VERSION = '0';

has [ qw/ tag_list
          amp_rows
          tag_totals
          tag_totals_pct /    ] =>  (isa => 'ArrayRef',
                               is => 'rw',
                               default  => sub { return []; },
                               );

has [ qw/ lane_bam_file
          tags_filename
          reporters_filename / ] => (isa => 'Maybe[Str]',
                                         is =>  'rw',
                                         );

no Moose;

1;

__END__


=head1 NAME

 npg_qc::autoqc::results::tags_reporters

=head1 SYNOPSIS

 my $rObj = npg_qc::autoqc::results::tags_reporters->new(id_run => 6551, position => 1, path => q[my_path]);

=head1 DESCRIPTION

 An autoqc result object that checks runs that test tag sets. Reports counts of pairs of
 tags and sequences.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Readonly

=item npg_qc::autoqc::results::result

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Kevin Lewis E<lt>kl2@sanger.ac.ukE<gt><gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013 GRL, by Kevin Lewis

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
