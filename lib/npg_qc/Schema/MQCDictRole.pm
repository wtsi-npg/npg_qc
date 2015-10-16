package npg_qc::Schema::MQCDictRole;

use strict;
use warnings;
use Readonly;
use base 'Exporter';

our $VERSION = '0';

use Moose::Role;

our @EXPORT_OK = qw/
                    $OUTCOME_ACCEPTED_FINAL
                    $OUTCOME_REJECTED_FINAL
                    $OUTCOME_UNDECIDED_FINAL
                   /;

Readonly::Scalar our $OUTCOME_ACCEPTED_FINAL  => q[Accepted final];
Readonly::Scalar our $OUTCOME_REJECTED_FINAL  => q[Rejected final];
Readonly::Scalar our $OUTCOME_UNDECIDED_FINAL => q[Undecided final];

requires 'short_desc';

sub is_final_outcome {
  my $self = shift;
  return $self->short_desc =~ m{final}ism; #The short description includes the word final.
}

sub is_accepted {
  my $self = shift;
  return $self->short_desc =~ m{accepted}ism; #The short description includes the word accepted.
}

sub is_rejected {
  my $self = shift;
  return $self->short_desc =~ m{rejected}ism; #The short description includes the word rejected.
}

sub is_final_accepted {
  my $self = shift;
  return $self->is_final_outcome && $self->is_accepted;
}

sub is_undecided {
  my $self = shift;
  return $self->short_desc =~ m{undecided}ism;
}

no Moose;
1;

__END__


=head1 NAME

  npg_qc::Schema::MQCDictRole

=head1 SYNOPSIS


=head1 DESCRIPTION

  Role for dictionaries in MQC

=head1 SUBROUTINES/METHODS

=head2 is_final_outcome

  Utility method to check if the outcome is considered final.

=head2 is_accepted

  Utility method which checks the short description to decide if the outcome can
  be considered accepted.

=head2 is_rejected

  Utility method which checks the short description to decide if the outcome can
  be considered rejected.

=head2 is_final_accepted

  Utility method which checks the short description to decide if the outcome can
  be considered final and accepted.

=head2 is_undecided

  Utility method which checks the short description to decide if the outcome can
  be considered as undecided.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Moose::Role

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Jaime Tovar <lt>jmtc@sanger.ac.uk<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 Genome Research Ltd

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
