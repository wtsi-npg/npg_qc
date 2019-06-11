package npg_qc::Schema::Mqc::OutcomeDict;

use Moose::Role;
use Readonly;
use Carp;

our $VERSION = '0';

Readonly::Scalar my $FINAL       => 'final';
Readonly::Scalar my $PRELIMINARY => 'preliminary';
Readonly::Scalar my $ACCEPTED    => 'Accepted';
Readonly::Scalar my $REJECTED    => 'Rejected';
Readonly::Scalar my $UNDECIDED   => 'Undecided';

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
  return $self->short_desc =~ /\A $ACCEPTED/smx; #The short description includes the word accepted.
}

sub is_rejected {
  my $self = shift;
  return $self->short_desc =~ /\A $REJECTED/smx; #The short description includes the word rejected.
}

sub is_final_accepted {
  my $self = shift;
  return $self->is_final_outcome && $self->is_accepted;
}

sub is_undecided {
  my $self = shift;
  return $self->short_desc =~ /\A $UNDECIDED/smx;
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

sub generate_short_description {
  my ($self, $is_final, $is_accepted) = @_;

  defined $is_final or croak 'Final flag should be defined';
  my $decision = $is_accepted ? $ACCEPTED :
        (defined $is_accepted ? $REJECTED : $UNDECIDED);
  if (defined $is_accepted || $is_final) {
    $decision .= q[ ] . ($is_final ? $FINAL : $PRELIMINARY);
  }

  return $decision;
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

=head2 generate_short_description

  Package-level method for generating descriptions matching short
  descriptions in the dictionary tables. Note that not every description
  is available in all dictionary tables.

    my $is_final = 1;
    my $is_accepted = 1;

    __PACKAGE__->generate_short_description($is_final, $is_accepted);
    # returns 'Accepted final'

    __PACKAGE__->generate_short_description($is_final);
    # returns 'Undecided final'

    $is_accepted = 0;
    __PACKAGE__->generate_short_description($is_final);
    # returns 'Rejected final'

    $is_final = 0;
    __PACKAGE__->generate_short_description($is_final, $is_accepted);
    # returns 'Rejected preliminary'

    __PACKAGE__->generate_short_description($is_final);
    # returns 'Undecided' !!!

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Readonly

=item Carp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Jaime Tovar <lt>jmtc@sanger.ac.uk<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2019 Genome Research Ltd

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
