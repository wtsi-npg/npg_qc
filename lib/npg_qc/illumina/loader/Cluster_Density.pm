#########
# Author:        gq1
# Maintainer:    $Author: mg8 $
# Created:       2010-01-27
# Last Modified: $Date: 2013-09-26 12:37:25 +0100 (Thu, 26 Sep 2013) $
# Id:            $Id: Cluster_Density.pm 17529 2013-09-26 11:37:25Z mg8 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/illumina/loader/Cluster_Density.pm $
#

package npg_qc::illumina::loader::Cluster_Density;

use Moose;
use Carp;
use English qw{-no_match_vars};
use Readonly;

extends 'npg_qc::illumina::loader::base';

our $VERSION = do { my ($r) = q$Revision: 17529 $ =~ /(\d+)/mxs; $r; };

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::illumina::loader::Cluster_Density

=head1 VERSION

$Revision: 17529 $

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
   my $query = q{SELECT id_run, count(*) AS c FROM cluster_density GROUP BY id_run HAVING c = 16};
   my $rows_ref = $self->dbh->selectall_arrayref($query);
   if($rows_ref) {
     foreach my $row_ref (@{$rows_ref}){
       $runlist_db->{$row_ref->[0]} = 1;
     }
   }
   return $runlist_db;
}

=head2 raw_xml_file

  raw cluster density by lane xml file name
=cut
has 'raw_xml_file' => (isa => q{Str},
                       is => q{rw},
                       lazy_build => 1,
                      );
sub _build_raw_xml_file {
  my $self = shift;
  return $self->reports_path().q{/NumClusters By Lane.xml};
}

=head2 pf_xml_file

  pf cluster density by lane xml file name

=cut
has 'pf_xml_file' => (isa => q{Str},
                      is => q{rw},
                      lazy_build => 1,
                     );
sub _build_pf_xml_file {
  my $self = shift;
  return $self->reports_path().q{/NumClusters By Lane PF.xml};
}

=head2 run
	
loads one run cluster density data
 	 	
=cut
sub run {
  my ($self) = @_;
  $self->mlog(q{Loading Illumina cluster density data for Run } . $self->id_run() . q{ into QC database});
  $self->save_to_db_list($self->parsing_xml($self->raw_xml_file()), 0);
  $self->save_to_db_list($self->parsing_xml($self->pf_xml_file()), 1);
  return;
}

=head2 parsing_xml

given one cluster dessity xml file, return a hashref

=cut

sub parsing_xml {
  my ($self, $xml) = @_;

  my $cluster_density_by_lane = {};
  my $xml_dom = $self->parser->parse_file( $xml );
  my @lane_list = $xml_dom->getElementsByTagName('Lane');
  foreach my $lane (@lane_list){
    my $key = $lane->getAttribute('key');
    my $min = $lane->getAttribute('min');
    my $max = $lane->getAttribute('max');
    my $p50 = $lane->getAttribute('p50');
    $cluster_density_by_lane->{$key}->{min} = $min;
    $cluster_density_by_lane->{$key}->{max} = $max;
    $cluster_density_by_lane->{$key}->{p50} = $p50;
  }
  return $cluster_density_by_lane;
}

=head2 save_to_db_list

given a hash list and whether this list is for pf cluster, save them to database

=cut
sub save_to_db_list{
  my ($self, $cluster_density_by_lane, $is_pf) = @_;
  foreach my $lane (keys %{$cluster_density_by_lane}){
    my $lane_values = $cluster_density_by_lane->{$lane};
    $self->save_to_db({lane => $lane,
                       is_pf=> $is_pf,
                       min  => $lane_values->{min},
                       max  => $lane_values->{max},
                       p50  => $lane_values->{p50},
                      });
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
