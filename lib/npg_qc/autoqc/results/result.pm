#########
# Author:        Marina Gourtovaia
# Maintainer:    $Author: mg8 $
# Created:       14 April 2009
# Last Modified: $Date: 2013-01-10 14:09:35 +0000 (Thu, 10 Jan 2013) $
# Id:            $Id: result.pm 16446 2013-01-10 14:09:35Z mg8 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/autoqc/results/result.pm $
#

package npg_qc::autoqc::results::result;

use Moose;
use MooseX::AttributeHelpers;

use npg_tracking::util::types;

with qw(
         npg_qc::autoqc::role::result
         npg_tracking::glossary::tag
       );

our $VERSION    = do { my ($r) = q$Revision: 16446 $ =~ /(\d+)/smx; $r; };
## no critic (Documentation::RequirePodAtEnd)


=head1 NAME

npg_qc::autoqc::results::result

=head1 VERSION

$Revision: 16446 $

=head1 SYNOPSIS

 my $r = npg_qc::autoqc::results::result->new(id_run => 1934, position => 5, path => q[mypath]);
 $r->pass(1); #set the pass value
 $r->equals_byvalue({id_run => 1934, position => 4,}); #returns false
 $r->equals_byvalue({id_run => 1934, position => 5,}); #returns true
 my $r = npg_qc::autoqc::results::result->load(q[my.json]);
 my $json_string = $r->freeze();

=head1 DESCRIPTION

A base class to wrap the result of autoqc.

=head1 SUBROUTINES/METHODS

=cut


=head2 pass

Pass or fail or undefined if cannot evaluate

=cut
has 'pass'         => (isa      => 'Maybe[Bool]',
                       is       => 'rw',
                       required => 0,
                      );


=head2 path

A path to a directory with fastq input files.

=cut
has 'path'        => (isa      => 'Str',
                      is       => 'rw',
                      required => 1,
                     );

=head2 position

Lane number. An integer from 1 to 8 inclusive.

=cut
has 'position'    => (isa      => 'NpgTrackingLaneNumber',
                      is       => 'rw',
                      required => 1,
                     );


=head2 id_run

Run id for the lane to be checked.

=cut
has 'id_run'      => (
                      isa      => 'NpgTrackingRunId',
                      is       => 'rw',
                      required => 1,
		     );

=head2 info

To store version number and other information

=cut

has 'info'     => (
      metaclass => 'Collection::Hash',
      is        => 'ro',
      isa       => 'HashRef[Str]',
      default   => sub { {} },
      provides  => {
          exists    => 'exists_in_info',
          keys      => 'ids_in_info',
          get       => 'get_info',
          set       => 'set_info',
      },
);

=head2 comments

A string containing comments, if any.

=cut
has 'comments'     => (isa => 'Maybe[Str]',
                       is => 'rw',
                       required => 0,
                      );

no Moose;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item npg_tracking::util::types

=item npg_tracking::glossary::tag

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Marina Gourtovaia

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
