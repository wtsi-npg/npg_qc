
package npg_qc::Schema::Result::MqcLibraryOutcomeEnt;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::MqcLibraryOutcomeEnt

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 ADDITIONAL CLASSES USED

=over 4

=item * L<namespace::autoclean>

=back

=cut

use namespace::autoclean;

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components('InflateColumn::DateTime');

=head1 TABLE: C<mqc_library_outcome_ent>

=cut

__PACKAGE__->table('mqc_library_outcome_ent');

=head1 ACCESSORS

=head2 id_mqc_library_outcome_ent

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_run

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 position

  data_type: 'tinyint'
  extra: {unsigned => 1}
  is_nullable: 0

Lane

=head2 tag_index

  data_type: 'bigint'
  is_nullable: 0

=head2 id_mqc_outcome

  data_type: 'smallint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 username

  data_type: 'char'
  is_nullable: 1
  size: 128

Web interface username

=head2 last_modified

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=head2 modified_by

  data_type: 'char'
  is_nullable: 1
  size: 128

Last user to modify the row

=head2 reported

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  is_nullable: 1

When was reported to LIMS

=cut

__PACKAGE__->add_columns(
  'id_mqc_library_outcome_ent',
  {
    data_type => 'bigint',
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  'id_run',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 0 },
  'position',
  { data_type => 'tinyint', extra => { unsigned => 1 }, is_nullable => 0 },
  'tag_index',
  { data_type => 'bigint', is_nullable => 0 },
  'id_mqc_outcome',
  { data_type => 'smallint', extra => { unsigned => 1 }, is_nullable => 0 },
  'username',
  { data_type => 'char', is_nullable => 1, size => 128 },
  'last_modified',
  {
    data_type => 'timestamp',
    datetime_undef_if_invalid => 1,
    default_value => \'current_timestamp',
    is_nullable => 0,
  },
  'modified_by',
  { data_type => 'char', is_nullable => 1, size => 128 },
  'reported',
  {
    data_type => 'timestamp',
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_mqc_library_outcome_ent>

=back

=cut

__PACKAGE__->set_primary_key('id_mqc_library_outcome_ent');

=head1 UNIQUE CONSTRAINTS

=head2 C<id_run_UNIQUE>

=over 4

=item * L</id_run>

=item * L</position>

=item * L</tag_index>

=back

=cut

__PACKAGE__->add_unique_constraint('id_run_UNIQUE', ['id_run', 'position', 'tag_index']);


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2015-08-21 18:34:16
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:oez7kRAijKJ7Np/nPWcfgA

# You can replace this text with custom code or comments, and it will be preserved on regeneration
our $VERSION = '0';

use Carp;
use DateTime;
use DateTime::TimeZone;

sub _get_time_now {
  return DateTime->now(time_zone=> DateTime::TimeZone->new(name => q[local]));
}

around 'update' => sub {
  my $orig = shift;
  my $self = shift;
  $self->last_modified($self->_get_time_now);
  my $return_super = $self->$orig(@_);

  $self->_create_historic();
  return $return_super;
};

around 'insert' => sub {
  my $orig = shift;
  my $self = shift;
  $self->last_modified($self->_get_time_now);
  my $return_super = $self->$orig(@_);

  $self->_create_historic();
  return $return_super;
};

sub update_outcome {
  my ($self, $outcome, $username) = @_;

  #Validation
  if(!defined $outcome){
    croak q[Mandatory parameter 'outcome' missing in call];
  }
  if(!defined $username){
    croak q[Mandatory parameter 'username' missing in call];
  }
  if ($username =~ /^\d+$/smx) {
    croak "Have a number $username instead as username";
  }
  my $outcome_dict_obj = $self->_valid_outcome($outcome);
  if($outcome_dict_obj) { # The new outcome is a valid one
    my $outcome_id = $outcome_dict_obj->id_mqc_outcome;
    #There is a row that matches the id_run and position
    if ($self->in_storage) {
      #Check if previous outcome is not final
      if($self->mqc_outcome->is_final_outcome) {
        croak(sprintf 'Error while trying to update a final outcome for id_run %i position %i',
              $self->id_run, $self->position);
      } else { #Update
        $self->update({'id_mqc_outcome' => $outcome_id, 'username' => $username, 'modified_by' => $username});
      }
    } else { #Is a new row just insert.      
      $self->id_mqc_outcome($outcome_id);
      $self->username($username);
      $self->modified_by($username);
      $self->insert();
    }
  } else {
    croak(sprintf 'Error while trying to transit id_run %i position %i to a non-existing outcome "%s".',
          $self->id_run, $self->position, $outcome);
  }
  return 1;
}

sub has_final_outcome {
  my $self = shift;
  return $self->mqc_outcome->is_final_outcome;
}

sub is_accepted {
  my $self = shift;
  return $self->mqc_outcome->is_accepted;
}

sub is_final_accepted {
  my $self = shift;
  return $self->mqc_outcome->is_final_accepted;
}

#Create and save historic from the entity current data.
sub _create_historic {
  my $self = shift;
  my $rs = $self->result_source->schema->resultset('MqcLibraryOutcomeHist');
  my $historic = $rs->create({
    id_run         => $self->id_run,
    position       => $self->position,
    id_mqc_outcome => $self->id_mqc_outcome,
    username       => $self->username,
    last_modified  => $self->last_modified,
    modified_by    => $self->modified_by});

  return 1;
}

#Fetches valid outcome object from the database.
sub _valid_outcome {
  my ($self, $outcome) = @_;

  my $rs = $self->result_source->schema->resultset('MqcOutcomeDict');
  my $outcome_dict;
  if ($outcome =~ /\d+/xms) {
    $outcome_dict = $rs->find($outcome);
  } else {
    $outcome_dict = $rs->search({short_desc => $outcome})->next;
  }
  if ((defined $outcome_dict) && $outcome_dict->iscurrent) {
    return $outcome_dict;
  }
  return;
}

__PACKAGE__->meta->make_immutable;

1;
