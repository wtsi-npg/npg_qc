package npg_qc::autoqc::qc_store::query;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Carp;

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

has 'npg_tracking_schema' => ( isa       => 'npg_tracking::Schema',
                               is        => 'ro',
                               required  => 1,
                             );

has 'db_qcresults_lookup' => (isa     => 'Bool',
                              is      => 'ro',
                              default => 1,
                             );

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
  $s .= q[, db_qcresults_lookup ] . $self->db_qcresults_lookup;

  return $s;
}

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

npg_qc::autoqc::qc_store::query

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

=head2 BUILD

Called before returning an object to the caller, does some sanity checking.

=head2 to_string

Human friendly description of object.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item Carp

=item npg_qc::autoqc::qc_store::options

=item npg_tracking::util::types

=item npg_tracking::glossary::run

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 GRL

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
