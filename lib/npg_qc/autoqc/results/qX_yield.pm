package npg_qc::autoqc::results::qX_yield;

use Moose;
use namespace::autoclean;
use npg_tracking::util::types;

extends qw(npg_qc::autoqc::results::result);
with qw ( npg_qc::autoqc::role::qX_yield );

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)


=head1 NAME

npg_qc::autoqc::results::qX_yield

=head1 SYNOPSIS


=head1 DESCRIPTION

A class for wrapping results of qX check. Inherits from npg_qc::autoqc::results::result.

=head1 SUBROUTINES/METHODS

=cut

Readonly::Scalar my $DEFAULT_THRESHOLD_Q => 20;


=head2 threshold_quality

Quality threshold

=cut
has 'threshold_quality'  => (
  isa             => 'Maybe[NpgTrackingPositiveInt]',
  is              => 'rw',
  required        => 0,
  default         => $DEFAULT_THRESHOLD_Q,
);

=head2 threshold_yield1

Yield threshold in KBs for the first (forward) read

=head2 threshold_yield2

Yield threshold in KBs for the second (reverse) read

=cut
has [qw(threshold_yield1 threshold_yield2)] => (
  isa      => 'Maybe[NpgTrackingNonNegativeInt]',
  is       => 'rw',
  required => 0,
);

=head2 yield1

Q20 yield in KBs for the first (forward) read

=head2 yield2

Q20 yield in KBs for the second (reverse) read

=head2 yield1_q30

Q30 yield in KBs for the first (forward) read

=head2 yield2_q30

Q30 yield in KBs for the second (reverse) read

=head2 yield1_q40

Q40 yield in KBs for the first (forward) read

=head2 yield2_q40

Q40 yield in KBs for the second (reverse) read

=cut
has [qw(yield1 yield2 yield1_q30 yield2_q30 yield1_q40 yield2_q40)] => (
  isa      => 'Maybe[NpgTrackingNonNegativeInt]',
  is       => 'rw',
  required => 0,
);

=head2 filename1

Filename for the first (forward) read

=head2 filename2

Filename for the second (reverse) read 

=cut
has [qw(filename1  filename2)] => (
  isa      => 'Maybe[Str]',
  is       => 'rw',
  required => 0,
);

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item npg_tracking::util::types

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
