#########
# Author:        Marina Gourtovaia
# Maintainer:    $Author: mg8 $
# Created:       28 September 2011
# Last Modified: $Date: 2013-01-10 14:09:35 +0000 (Thu, 10 Jan 2013) $
# Id:            $Id: query.pm 16446 2013-01-10 14:09:35Z mg8 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/autoqc/qc_store/query.pm $
#

package npg_qc::autoqc::qc_store::query;

use strict;
use warnings;
use Carp;
use Moose;
use Readonly;

use npg_qc::autoqc::qc_store::options qw/$ALL $LANES $PLEXES/;
use npg_tracking::util::types;
with qw/npg_tracking::glossary::run/;

our $VERSION = '0';

has 'option'    =>   (isa       => 'Int',
                      is        => 'ro',
                      default   => $LANES,
                     );

has 'positions' =>   (isa       => 'ArrayRef[NpgTrackingLaneNumber]',
                      is        => 'ro',
                      default   => sub {return []; },
                     );

has 'npg_tracking_schema' => ( isa => 'Maybe[npg_tracking::Schema]',
                               is  => 'ro',
                               documentation => 'NPG tracking DBIC schema',
                             );

has 'db_qcresults_lookup' => (isa  => 'Bool', is => 'ro', default => 1,);

has 'propagate_npg_tracking_schema' => (isa  => 'Bool', is => 'rw', default => 0,);

sub BUILD {
  my $self = shift;
  if ($self->option != $ALL && $self->option != $PLEXES && $self->option != $LANES) {
    croak q[Unknown option for loading qc results: ] . $self->option;
  }
}

sub to_string {
  my $self = shift;

  my $s = __PACKAGE__ . q[ object: run ] . $self->id_run;

  my $positions = @{$self->positions} ? (join q[ ], @{$self->positions}) : q[ALL];
  $s .= qq[, positions $positions];

  my $option = $self->option == $LANES  ? q[LANES] :
               $self->option == $ALL    ? q[ALL]   : q[PLEXES];
  $s .= qq[, loading option $option];

  my $schema = $self->npg_tracking_schema;
  my $schema_string = $schema && (ref $schema) ? qq[$schema] : q[UNDEFINED];
  $s .= qq[, npg_tracking_schema $schema_string];

  $s .= q[, propagate_npg_tracking_schema ] . $self->propagate_npg_tracking_schema;
  $s .= q[, db_qcresults_lookup ] . $self->db_qcresults_lookup;

  return $s;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__


=head1 NAME

npg_qc::autoqc::qc_store::query

=head1 VERSION

$Revision: 16446 $

=head1 SYNOPSIS

=head1 DESCRIPTION

A wrapper for retrival options and parameters for autoqc results

=head1 SUBROUTINES/METHODS

=head2 option

Option for loading autoqc results, one of constants defined in npg_qc::autoqc::qc_store::options.

=head2 id_run

=head2 positions

A reference to an array with positions (lane numbers).

=head2 npg_tracking_schema

An instance of npg_tracking::Schema, undefined by default.

=head2 db_qcresults_lookup

A boolens flag indicating whether to look for autoqc results in a database.

=head2 propagate_npg_tracking_schema

A boolean flag indicating whether the value of the npg_tracking_schema attribute
should be passed to the code that gets the location of a runfolder. Set to false
by default. 

=head2 BUILD

Called before returning an object to the caller, does some sanity checking.

=head2 to_string

Human friendly description of object.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Readonly

=item Moose

=item Carp

=item npg_qc::autoqc::qc_store::options

=item npg_tracking::util::types

=item npg_tracking::glossary::run

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 GRL, by Marina Gourtovaia

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
