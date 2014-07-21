#########
# Author:        gq1
# Created:       2010-01-27
#

package npg_qc::illumina::loader::Cluster_Density;

use Moose;
use Carp;
use English qw{-no_match_vars};
use Readonly;

extends 'npg_qc::illumina::loader::base';

our $VERSION = '0';

#keys used in hash and corresponding codes in tile metrics interop file
Readonly::Scalar our $TILE_METRICS_INTEROP_CODES => {'cluster density'    => 100,
                                                     'cluster density pf' => 101,
                                                     'cluster count'      => 102,
                                                     'cluster count pf'   => 103,
                                                     };

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::illumina::loader::Cluster_Density

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 _build_runlist_db

lazy build method

id_run list already in the database
 
=cut

sub _build_runlist_db {
   my $self = shift;
   my $runlist_db = {};
   my $query = q{SELECT id_run, count(*) AS c FROM cluster_density GROUP BY id_run};
   my $rows_ref = $self->dbh->selectall_arrayref($query);
   if($rows_ref) {
     foreach my $row_ref (@{$rows_ref}){
       my $run_lane = $self->schema_npg_tracking->resultset( q(RunLane) )->search( { id_run => $row_ref->[0] } );
       my $expected = 2 * $run_lane->count;
       if ($expected == $row_ref->[1]) {
         $runlist_db->{$row_ref->[0]} = 1;
       }
     }
   }
   return $runlist_db;
}

=head2 tile_metrics_interop_file

  tile metrics interop file name
=cut
has 'tile_metrics_interop_file' => (isa => q{Str},
                       is => q{rw},
                       lazy_build => 1,
                      );
sub _build_tile_metrics_interop_file {
  my $self = shift;
  return $self->runfolder_path().q{/InterOp/TileMetricsOut.bin};
}

=head2 run
	
loads one run cluster density data
 	 	
=cut
sub run {
  my ($self) = @_;
  $self->mlog(q{Loading Illumina cluster density data for Run } . $self->id_run() . q{ into QC database});
  $self->save_to_db_list($self->parsing_interop($self->tile_metrics_interop_file));
  return;
}

=head2 parsing_interop

given one tile metrics interop file, return a hashref

=cut
sub parsing_interop {
  my ($self, $interop) = @_;

  my $cluster_density_by_lane = {};

  my $version;
  my $length;
  my $data;

  my $template = 'v3f'; # three two-byte integers and one 4-byte float

  ## no critic (InputOutput::RequireBriefOpen)
  open my $fh, q{<}, $interop or croak qq{Couldn't open interop file $interop, error $ERRNO};
  binmode $fh, ':raw';

  $fh->read($data, 1) or croak qq{Couldn't read file version in interop file $interop, error $ERRNO};
  $version = unpack 'C', $data;

  $fh->read($data, 1) or croak qq{Couldn't read record length in interop file $interop, error $ERRNO};
  $length = unpack 'C', $data;

  my $tile_metrics = {};

  while ($fh->read($data, $length)) {
    my ($lane,$tile,$code,$value) = unpack $template, $data;
    if( $code == $TILE_METRICS_INTEROP_CODES->{'cluster density'} ){
      push @{$tile_metrics->{$lane}->{'cluster density'}}, $value;
    }elsif( $code == $TILE_METRICS_INTEROP_CODES->{'cluster density pf'} ){
      push @{$tile_metrics->{$lane}->{'cluster density pf'}}, $value;
    }
  }

  $fh->close() or croak qq{Couldn't close interop file $interop, error $ERRNO};

  my $lanes = scalar keys %{$tile_metrics};
  if( $lanes == 0){
    $self->mlog( 'No cluster density data' );
    return $cluster_density_by_lane;
  }

  # calc lane stats
  foreach my $lane (keys %{$tile_metrics}){
    for my $code (keys %{$tile_metrics->{$lane}}) {
      my @values = sort {$a<=>$b} @{$tile_metrics->{$lane}->{$code}};
      my $nvalues = scalar @values;
      my $n50 = int $nvalues / 2;
      my $min = $values[0];
      my $max = $values[$nvalues-1];
      my $p50 = ($nvalues % 2 ? $values[$n50] : ($values[$n50-1]+$values[$n50]) / 2);
      $cluster_density_by_lane->{$lane}->{$code}->{min} = $min;
      $cluster_density_by_lane->{$lane}->{$code}->{max} = $max;
      $cluster_density_by_lane->{$lane}->{$code}->{p50} = $p50;
    }
  }

  return $cluster_density_by_lane;
}

=head2 save_to_db_list

given a hash list of cluster densities, save them to database

=cut
sub save_to_db_list{
  my ($self, $cluster_density_by_lane) = @_;
  foreach my $lane (keys %{$cluster_density_by_lane}){
    for my $is_pf (0, 1) {
      my $lane_values = $cluster_density_by_lane->{$lane}->{$is_pf};
      $self->save_to_db({lane => $lane,
                         is_pf=> $is_pf,
                         min  => $lane_values->{min},
                         max  => $lane_values->{max},
                         p50  => $lane_values->{p50},
                        });
    }
  }
  return;
}

=head2 save_to_db

given one row of data, save it into database

=cut
sub save_to_db{
  my ($self, $args_ref) = @_;

  my $id_run = $self->id_run();
  my $lane   = $args_ref->{lane};
  my $is_pf  = $args_ref->{is_pf};
  my $min    = $args_ref->{min};
  my $max    = $args_ref->{max};
  my $p50    = $args_ref->{p50};

  my $query = q{INSERT INTO cluster_density (id_run, position, is_pf, min, max, p50)
                VALUES (?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                id_run = ?,
                position = ?,
                is_pf = ?,
                min = ?,
                max = ?,
                p50 = ?
                };
  my $sth1 = $self->dbh->prepare_cached($query);
  $sth1->execute($id_run, $lane, $is_pf, $min, $max, $p50,
                 $id_run, $lane, $is_pf, $min, $max, $p50);
  return;
}

=head2 run_all

loads all eligible runs cluster density data
 
=cut
sub run_all {
  my $self = shift;
  $self->mlog('Finding runfolder with cluster density files and load them into QC database');
  $self->mlog('There are '. ( scalar keys %{$self->runfolder_list_todo} ).' runs to do' );
  foreach my $id_run (keys %{$self->runfolder_list_todo}) {

    eval{
      __PACKAGE__->new(
                       runfolder_path => $self->runfolder_list_todo->{$id_run},
                       id_run         => $id_run,
                       schema         => $self->schema,
      )->run();
      1;
    } or do {
      if( $EVAL_ERROR =~ /No\ such\ file\ or\ directory/mxs){
        $self->mlog( 'No cluster density file available' );
      }else{
        croak $EVAL_ERROR;
      }
    };
  }
  return;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item English qw{-no_match_vars}

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi, E<lt>gq1@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Guoying Qi

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
