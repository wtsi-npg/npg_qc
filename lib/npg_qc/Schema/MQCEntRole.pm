package npg_qc::Schema::MQCEntRole;

use strict;
use warnings;
use Carp;
use Readonly;
use base 'Exporter';

our $VERSION = '0';

use Moose::Role;

with qw/npg_qc::Schema::TimeZoneConsumerRole/;

our @EXPORT_OK = qw/
                    $MQC_OUTCOME_DICT
                    $MQC_LANE_ENT
                    $MQC_LANE_HIST
                    $MQC_LIBRARY_OUTCOME_DICT
                    $MQC_LIBRARY_ENT
                    $MQC_LIBRARY_HIST
                    $MQC_LIB_LIMIT
                    $MQC_USER_ROLE
                   /;

#Result names
Readonly::Scalar our $MQC_OUTCOME_DICT         => q[MqcOutcomeDict];
Readonly::Scalar our $MQC_LANE_ENT             => q[MqcOutcomeEnt];
Readonly::Scalar our $MQC_LANE_HIST            => q[MqcOutcomeHist];
Readonly::Scalar our $MQC_LIBRARY_OUTCOME_DICT => q[MqcLibraryOutcomeDict];
Readonly::Scalar our $MQC_LIBRARY_ENT          => q[MqcLibraryOutcomeEnt];
Readonly::Scalar our $MQC_LIBRARY_HIST         => q[MqcLibraryOutcomeHist];

#MQC general configuration
Readonly::Scalar our $MQC_LIB_LIMIT    => 50;
Readonly::Scalar our $MQC_USER_ROLE         => q[manual_qc];

requires 'short_desc';
requires 'update';
requires 'insert';
requires 'historic_resultset';

Readonly my %DELEGATION_TO_MQC_OUTCOME = (
  'has_final_outcome' => 'is_final_outcome',
  'is_accepted'       => 'is_accepted',
  'is_final_accepted' => 'is_final_accepted',
  'is_undecided'      => 'is_undecided',
);

foreach my $this_class_method (keys %DELEGATION_TO_MQC_OUTCOME ) {
  __PACKAGE__->meta->add_method( $this_class_method,
    sub {
      my $self = shift;
      my $that_class_method = $DELEGATION_TO_MQC_OUTCOME{$this_class_method};
      my $dictionary_relationship_name = $self->get_dictionary_relationship_name;
      my $dictionary = $self->${dictionary_relationship_name};
      $dictionary->$that_class_method;
    }
  );
}

around [qw/update insert/] => sub {
  my $orig = shift;
  my $self = shift;
  $self->last_modified($self->get_time_now);
  my $return_super = $self->$orig(@_);

  $self->_create_historic();
  return $return_super;
};

sub data_for_historic {
  my $self = shift;
  my $my_cols = {$self->get_columns};
  my @hist_cols = $self->result_source
                       ->schema
                       ->source($self->historic_resultset)
                       ->columns;
  my $vals = {}; #TODO Nicer way to do this?
  foreach my $x (@hist_cols) {
    if ( exists $my_cols->{$x} ) {
      $vals->{$x} = $my_cols->{$x};
    }
  }
  return $vals;
}

sub validate_username {
  my ( $self, $username ) = @_;

  if(!defined $username){
    croak q[Mandatory parameter 'username' missing in call];
  }
  if ($username =~ /^\d+$/smx) {
    croak "Have a number $username instead as username";
  }
  return;
}

#TODO implement a toggle_outcome method

#Create and save historic from the entity current data.
sub _create_historic {
  my $self = shift;
  my $rs = $self->result_source->schema->resultset($self->historic_resultset);
  my $historic = $rs->create($self->data_for_historic);
  return 1;
}

no Moose;

1;

__END__


=head1 NAME

  npg_qc::Schema::MQCEntRole

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=head2 data_for_historic

  Looks at the entity columns and the matching historic metadata to
  find those columns which intersect and copies from entity to a new
  hash intersecting values.

=head2 validate_username

  To make sure the username is alphanumeric

=head2 update_outcome

  Updates the outcome of the entity with values provided.

  $obj->($outcome, $username)

=head2 has_final_outcome

  Returns true id this entry corresponds to a final outcome, otherwise returns false.

=head2 is_accepted

  Returns the result of checking if the outcome is considered accepted. Delegates the 
  check to L<npg_qc::Schema::Result::MqcOutcomeDict>

=head2 is_final_accepted

  Returns the result of checking if the outcome is considered final and accepted. 
  Delegates the check to L<npg_qc::Schema::Result::MqcOutcomeDict>

=head2 is_undecided

  Returns true if the current outcome is undecided. 
  Delegates the check to L<npg_qc::Schema::Result::MqcOutcomeDict>

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Readonly

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
