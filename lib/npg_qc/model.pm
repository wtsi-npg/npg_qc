package npg_qc::model;
use strict;
use warnings;
use base qw(ClearPress::model);
use Carp;

our $VERSION = '0';

sub id_run {
  my ($self, $id_run) = @_;
  if (!$id_run) {
    $id_run = $self->{id_run};
    if (!$id_run) {
      my $class = ref $self;
      ($class) = $class =~ /(\w+)$/sxm;
    }
  }
  if ($id_run) {
    $self->{id_run} = $id_run;
  }
  return $id_run;
}

sub run_having_control_lane {
  return 0;
}

sub get_cycle_count_from_recipe{
  my ($self, $id_run, $end) = @_;

  my $actual_id_run = $id_run;

  my $query = q{SELECT cycle
                FROM   run_recipe
                WHERE  id_run = ?
                };

  my $dbh = $self->util->dbh();
  my $sth = $dbh->prepare($query);
  $sth->execute($actual_id_run);
  my $row_ref = $sth->fetchrow_arrayref();

  my $cycle;

  if($row_ref){
    $cycle = $row_ref->[0];
  }
  return $cycle;
}

sub get_single_read_length_from_recipe{
  my ($self, $id_run, $end) = @_;

  my $query = q{SELECT cycle_read1, cycle_read2, first_indexing_cycle, last_indexing_cycle
                FROM   run_recipe
                WHERE  id_run = ?
                };

  my $dbh = $self->util->dbh();
  my $sth = $dbh->prepare($query);
  $sth->execute($id_run);
  my @row = $sth->fetchrow_array();

  my $read_length;
  if(scalar @row){

    my $cycle_read1 = shift @row;
    my $cycle_read2 = shift @row;
    my $first_indexing_cycle = shift @row;
    my $last_indexing_cycle = shift @row;

    if($end == 1){
      $read_length = $cycle_read1;
    }elsif($end == 2){
      $read_length = $cycle_read2;
    }
  }
  return $read_length;
}

sub get_read_cycle_range_from_recipe {
  my ($self, $id_run, $end) = @_;

  if(!$end){
    $end = 0;
  }

  if(!$self->{get_read_cycle_range_from_recipe}->{$id_run}->{$end}){
    my $query = q{SELECT cycle, cycle_read1, cycle_read2, first_indexing_cycle, last_indexing_cycle
                  FROM   run_recipe
                  WHERE  id_run = ?
                };

    my $dbh = $self->util->dbh();
    my $sth = $dbh->prepare($query);
    $sth->execute($id_run);
    my @row = $sth->fetchrow_array();

    my $cycle_range;
    if(! scalar @row){
      return $cycle_range;
    }

    my $cycle = shift @row;
    my $cycle_read1 = shift @row;
    my $cycle_read2 = shift @row;
    my $first_indexing_cycle = shift @row;
    my $last_indexing_cycle = shift @row;

    $cycle_range = [1, $cycle];
    if($end eq q(1) && $cycle_read1){
      $cycle_range = [1, $cycle_read1];
    }elsif($end eq q(2) && $cycle_read2){
        $cycle_range = [$cycle_read1 + 1, $cycle];
        if($first_indexing_cycle && $last_indexing_cycle){
          $cycle_range = [$last_indexing_cycle + 1, $cycle];
        }
    }
    $self->{get_read_cycle_range_from_recipe}->{$id_run}->{$end} = $cycle_range;
  }
  return $self->{get_read_cycle_range_from_recipe}->{$id_run}->{$end};
}

sub get_single_read_length{
  my ($self, $id_run, $end) = @_;
  my $error = "Wrong end number for run $id_run: $end";
  # croak for t end moved here to avoid warnings in numeric comparison
  if ($end eq 't') { croak $error; }
  if($end == 1){
    return $self->get_single_read_length_from_recipe($id_run, 1);
  }elsif($end == 2){
    return $self->get_single_read_length_from_recipe($id_run, 2);
  }else{
    croak $error;
  }
  return 1;
}

1;
__END__

=head1 NAME

npg_qc::model - a base class for the npg_qc family, derived from ClearPress::model

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 run_having_control_lane  - given an id_run, check the run having control lane or not using npg api run

=head2 get_cycle_count_from_recipe - get cycle count from run recipe table based on id_run and end

=head2 get_read_length_from_recipe - get cycle details of each run in a string

=head2 get_read_cycle_range_from_recipe - get cycle number range for each read or the whole run

=head2 get_single_read_length_from_recipe - given an id_run and end, return the read length of that read, plus any indexing cycle number if it is the first read of that run.

=head2 get_single_read_length - given an id_run (smaller id_run if paired run) and end, return the read length of that read

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007 GRL

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
