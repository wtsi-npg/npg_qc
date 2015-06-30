#########
# Author:        gq1
# Created:       2008-12-05
#
package npg_qc::illumina::loader::Run_Timeline;

use Carp;
use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;
use Readonly;

use npg_tracking::Schema;
use npg_qc::Schema;

our $VERSION = '0';

Readonly::Scalar our $MINIMUM_ID_RUN => 9000;

has 'schema_npg_tracking' =>  (
                       isa        => 'npg_tracking::Schema',
                       is         => 'ro',
                       required   => 0,
                       lazy_build => 1,
                     );
sub _build_schema_npg_tracking {
  return npg_tracking::Schema->connect();
}

has 'schema'      => ( isa        => 'npg_qc::Schema',
                       is         => 'ro',
                       required   => 0,
                       lazy_build => 1,
                     );
sub _build_schema {
  return npg_qc::Schema->connect();
}

has 'id_run'        =>    ( isa      => 'ArrayRef[Int]',
                            is       => 'ro',
                            required => 0,
                            default  => sub { return []; },
                          );

has '_min_id_run'   =>    ( isa      => 'Int',
                            is       => 'ro',
                            required => 0,
                            default  => sub { return $MINIMUM_ID_RUN; },
                          );

has '_runs2load' =>   ( isa        => 'ArrayRef',
                        is         => 'ro',
                        required   => 0,
                        lazy_build => 1,
                      );
sub _build__runs2load {
  my $self = shift;

  if (@{$self->id_run}) {
    return $self->id_run;
  }
  my %where;
  $where{id_run}{'>'} = $self->_min_id_run;
  $where{id_run}{'not in'} = $self->_runs_with_timeline;
  my $runs_rs = $self->schema_npg_tracking->resultset('Run')->search(\%where);
  my @runs = ();
  while (my $run = $runs_rs->next()) {
    push @runs, $run->id_run();
  }

  my $all_runs = join q[ ],  @runs;
  warn qq[Runs to load: $all_runs\n];
  return \@runs;
}

has '_runs_with_timeline' =>    ( isa        => 'ArrayRef',
                                  is         => 'ro',
                                  required   => 0,
                                  lazy_build => 1,
                                );
sub _build__runs_with_timeline {
  my $self = shift;

  warn qq[Getting a list of runs already in the database...\n];
  my $runs_rs = $self->schema->resultset('RunTimeline')->search(
                          {id_run        => {q[>], $self->_min_id_run},
                           start_time    => {q[!=], undef},
                           complete_time => {q[!=], undef},
                           end_time      => {q[!=], undef}, });
  my @runs = ();
  while (my $run = $runs_rs->next()) {
    push @runs, $run->id_run();
  }
  return \@runs;
}

sub _save_run_timeline {
  my ($self, $id_run) = @_;
  if (!$id_run) {
    croak 'Run id should be defined';
  }

  my $rs_set =  $self->schema_npg_tracking->resultset('RunStatus')->search({id_run => $id_run,});
  my $info = { id_run => $id_run };
  $info->{start_time} = undef;
  $info->{complete_time} = undef;
  $info->{end_time} = undef;

  while (my $st = $rs_set->next) {
    my $date = $st->date;
    my $des = $st->run_status_dict->description();
    if($des eq 'run complete'){
      $info->{complete_time} = $date;
    } elsif ($des eq 'run mirrored'
	  || $des eq 'run cancelled'
	  || $des eq 'run quarantined'
	  || $des eq 'data discarded'
	  || $des eq 'run stopped early'
	                 ){
      $info->{end_time} = $date;
    } elsif ($des eq 'run pending'){
      $info->{start_time} = $date;
    }
  }

  if ($info->{start_time} || $info->{complete_time} || $info->{end_time}){
    $self->schema->resultset('RunTimeline')->update_or_create($info);
  } else {
    warn qq[No timeline data available for $id_run, not saved\n];
  }

  return 1;
}

sub save_dates {
  my $self = shift;
  foreach my $id_run (@{$self->_runs2load()}) {
    $self->_save_run_timeline($id_run);
  }
  warn q[Timeline saved for ] . scalar @{$self->_runs2load()} . qq[ runs\n];
  return 1;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

npg_qc::illumina::loader::Run_Timeline

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 schema_npg_tracking - npg trackign DBIx schema connection

=head2 schema - npg qc DBIx schema connection

=head2 id_run - An array ref of run ids that have to be loaded. If not set, all runs will be considered.

=head2 save_dates

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item MooseX::StrictConstructor

=item Carp

=item Readonly

=item npg_tracking::Schema

=item npg_qc::Schema

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi, E<lt>gq1@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Guoying Qi

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
