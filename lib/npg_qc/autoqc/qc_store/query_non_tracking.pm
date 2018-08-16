package npg_qc::autoqc::qc_store::query_non_tracking;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;

use npg_qc::autoqc::qc_store::options qw/ $LANES
                                          validate_option
                                          option_to_string /;
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

has 'db_qcresults_lookup' => (isa     => 'Bool',
                              is      => 'ro',
                              default => 1,
                             );

sub BUILD {
  my $self = shift;
  validate_option($self->option);
  return;
}

sub to_string {
  my $self = shift;

  my $s = __PACKAGE__ . q[ object: run ] . $self->id_run;
  my $positions = @{$self->positions} ? (join q[ ], @{$self->positions}) : q[ALL];
  $s .= qq[, positions $positions];
  $s .=  q[, loading option ] . option_to_string($self->option);
  $s .=  q[, db_qcresults_lookup ] . $self->db_qcresults_lookup;

  return $s;
}

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

npg_qc::autoqc::qc_store::query_non_tracking

=head1 SYNOPSIS

=head1 DESCRIPTION

A wrapper object for retrival parameters and options for autoqc results.

=head1 SUBROUTINES/METHODS

=head2 option

Option for loading autoqc results, one of constants defined in npg_qc::autoqc::qc_store::options.

=head2 id_run

=head2 positions

A reference to an array with positions (lane numbers).

=head2 db_qcresults_lookup

A boolens flag indicating whether to look for autoqc results in a database.

=head2 BUILD

Called before returning an object to the caller, does some sanity checking.

=head2 to_string

Human friendly description of the object.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

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
