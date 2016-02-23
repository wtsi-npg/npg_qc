package npg_qc::Schema::Mqc::OutcomeDict;

use Moose::Role;
use Carp;
use Readonly;

my $FINAL       = 'final';
my $PRELIMINARY = 'preliminary';

our $VERSION = '0';

sub is_final_outcome_description {
  my ($self, $desc) = @_;
  return $desc =~ /$FINAL\Z/smx; #The short description includes the word final.
}

sub is_final_outcome {
  my $self = shift;
  return $self->is_final_outcome_description($self->short_desc);
}

sub is_accepted {
  my $self = shift;
  return $self->short_desc =~ /\AAccepted/smx; #The short description includes the word accepted.
}

sub is_rejected {
  my $self = shift;
  return $self->short_desc =~ /\ARejected/smx; #The short description includes the word rejected.
}

sub is_final_accepted {
  my $self = shift;
  return $self->is_final_outcome && $self->is_accepted;
}

sub is_undecided {
  my $self = shift;
  return $self->short_desc =~ /\AUndecided/smx;
}

sub pk_value {
  my $self = shift;
  my @primary_columns = $self->primary_columns;
  my $column = shift @primary_columns;
  return $self->$column;
}

sub matching_final_short_desc {
  my $self = shift;

  my $desc = $self->short_desc;
  if (!$self->is_final_outcome) {
    my $count = $desc =~ s/$PRELIMINARY/$FINAL/xms;
    if (!$count) { # Undecided outcome does not have 'preliminary' suffix
      $desc .= " $FINAL";
    }
  }

  return $desc;
}

no Moose::Role;

1;

__END__


=head1 NAME

  npg_qc::Schema::Mqc::OutcomeDict

=head1 SYNOPSIS

  package OutcomeDict;
  with 'npg_qc::Schema::Mqc::OutcomeDict';

=head1 DESCRIPTION

  Common functionality for lane and library manual qc outcome dictionary DBIx objects.

=head1 SUBROUTINES/METHODS

=head2 is_final_outcome_description

  Argument - short qc outcome description.
  Returns true if the argument describes a final outcome, false otherwise.
  Can be used as both class and instance method.

  __PACKAGE__->is_final_outcome_description('Accepted final'); # returns true
  $row->is_final_outcome_description('Accepted preliminary'); # returns false

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

=head2 pk_value

  Returns the value of primary key for the object if the table was defined with
  a single column primary key. Croaks if there is no primary key column or if
  there is a multi column primary key.

=head2 matching_final_short_desc

  If this outcome is final, returns a short description of this outcome,
  otherwise returns a short description for a matching final outcome.
  The returned outcome description does not necessarily exist in a
  dictionary.
  
    print $dict_row->short_desc; # Rejected preliminary
    print $dict_row->matching_final_short_desc(); # Rejected final

    print $dict_row->short_desc; # Rejected final
    print $dict_row->matching_final_short_desc(); # Rejected final

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Jaime Tovar <lt>jmtc@sanger.ac.uk<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 Genome Research Ltd

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
