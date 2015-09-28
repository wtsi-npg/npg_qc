#########
# Author:        gq1
# Created:       2010-02-05
#
package npg_qc::illumina::loader::Bustard_Summary;

use Moose;
use namespace::autoclean;
use Carp;
use English qw{-no_match_vars};
use Readonly;

extends qw{npg_qc::illumina::loader::base};

our $VERSION = '0';

#field names used in xml and database for chip summary
Readonly::Scalar our $CHIP_SUMMARY_FIELDS_TO_LOAD => {clusterCountPF    => 'clusters_pf',
                                                      clusterCountRaw   => 'clusters',
                                                      yield             => 'yield_kb',
                                                      ChipID            => 'chip_id',
                                                      Machine           => 'machine',
                                                      };
#field names used in xml and database for lane_qc table but tile based data
Readonly::Scalar our $LANE_QC_FIELDS_TO_LOAD      => {clusterCountRaw   => 'clusters_raw',
                                                      oneSig            => 'av_1st_cycle_int_pf',
                                                      percentClustersPF => 'perc_pf_clusters',
                                                      signal20AsPctOf1  => 'av_perc_intensity_after_20_cycles_pf',
                                                     };

Readonly::Scalar our $LANE_SUMMARY_FIELDS_TO_LOAD => {clusterCountPF   => 'clusters_pf',
                                                      clusterCountRaw  => 'clusters_raw',
                                                      oneSig           => 'cycle1_int_pf',
                                                      percentClustersPF=> 'perc_clusters_pf',
                                                      signal20AsPctOf1 => 'cycle20_perc_int',
                                                     };

Readonly::Scalar our $LANE_EXPANDED_SUMMARY_FIELDS_TO_LOAD
                                                  => {prephasingApplied => 'perc_prephasing',
                                                      phasingApplied    => 'perc_phasing',
                                                     };
Readonly::Scalar our $LANE_EXPANDED_SUMMARY_FIELDS_NO_ERR_TO_LOAD
                                                  => {clusterCountRaw   => 'clusters_tilemean_raw',
                                                      percentClustersPF => 'perc_retained',
                                                     };
Readonly::Scalar our $LANE_EXPANDED_SUMMARY_FIELDS_WITH_ERROR_TO_LOAD
                                                  => {signalAverage2to4 => 'cycle_2_4_av_int_pf',
                                                      signalLoss2to10   => 'cycle_2_10_av_perc_loss_pf',
                                                      signalLoss10to20  => 'cycle_10_20_av_perc_loss_pf',
                                                     };
## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::illumina::loader::Bustard_Summary

=head1 SYNOPSIS

  my $oBustardSummary = npg_qc::illumina::loader::Bustard_Summary->new(
    run_folder => $sRunFolder,
  );

id_run or run_folder must be provided, or at least a path for npg_tracking::illumina::run::folder
which should expose the run_folder. verbose turns on the optional logs

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 xml_file

bustard summary xml file name
 
=cut
has 'xml_file'     => (isa           => q{Str},
                       is            => q{rw},
                       lazy_build    => 1,
                       documentation => q{file name for bustard summary xml},
                      );

sub _build_xml_file {
  my $self = shift;
  return $self->bustard_path().q{/BustardSummary.xml};
}


=head2 run
 
=cut

sub run {
  my ($self) = @_;
  my $xml_file_name = $self->xml_file();
  if(! -e $xml_file_name){
     $self->mlog("Bustard Summary XML not exist!\n$xml_file_name");
     return 1;
  }
  my $transaction = sub { $self->_parsing_xml($xml_file_name) };
  $self->schema->txn_do($transaction);
  return 1;
}

sub _parsing_xml {
  my ($self, $xml) = @_;

  my $xml_dom = $self->parser()->parse_file( $xml );

  #processing chip_summary data 
  my $chip_results_summary = $xml_dom->getElementsByTagName('ChipResultsSummary')->[0];
  my $chip_summary = $xml_dom->getElementsByTagName('ChipSummary')->[0];
  $self->_process_chip_summary($chip_results_summary, $chip_summary);

  #processing lane summary and expanded summary
  my $lane_result_summary = $xml_dom->getElementsByTagName('LaneResultsSummary')->[0];
  my $expanded_lane_summary = $xml_dom->getElementsByTagName('ExpandedLaneSummary')->[0];
  $self->_process_lane_summary($lane_result_summary, $expanded_lane_summary);

  #processing tile result by lane  
  my $tile_result_by_lane_element = $xml_dom->getElementsByTagName('TileResultsByLane')->[0];
  my $tile_result_by_lane_list= $tile_result_by_lane_element->getElementsByTagName('Lane');

  foreach my $lane (@{$tile_result_by_lane_list}){
    $self->_prosess_tile_result_by_lane($lane);
  }

  return 1;
}

sub _process_chip_summary{
  my ($self, $chip_results_summary, $chip_summary) = @_;

  $self->mlog(q{Processing chip summary data...});

  my @nodelist = ($chip_results_summary->childNodes(), $chip_summary->childNodes());
  my $chip_summary_db = {};

  foreach my $node (@nodelist){

    if($node->nodeType() == 1){

      my $node_content = $node->textContent;
      my $node_name = $node->nodeName();
      my $field_name_db = $CHIP_SUMMARY_FIELDS_TO_LOAD->{$node_name};
      if($field_name_db){
        $chip_summary_db->{$field_name_db} = $node_content;
      }
    }
  }

  $chip_summary_db->{id_run} = $self->id_run();
  $chip_summary_db->{paired} = $self->is_paired_read();

  $self->schema->resultset('ChipSummary')->update_or_create(
                                         $chip_summary_db
                                      );
  return 1;
}

sub _process_lane_summary{
  my ( $self, $lane_result_summary, $expanded_lane_summary ) = @_;

  my $lane_summary_db = {};

  $self->mlog('Processing lane results summary data');
  my $lane_result_summary_by_read = $lane_result_summary->getElementsByTagName('Read');
  foreach my $read (@{$lane_result_summary_by_read}){
     $self->_process_lane_result_summary_by_read($read , $lane_summary_db);
  }

  $self->mlog('Processing expanded lane summary data');
  my $expanded_lane_summary_by_read = $expanded_lane_summary->getElementsByTagName('Read');
  foreach my $read (@{$expanded_lane_summary_by_read}){
     $self->_process_expanded_lane_summary_by_read($read , $lane_summary_db);
  }

  $self->mlog('Populating lane summary data into database');
  foreach my $read (keys %{$lane_summary_db} ){

     my $id_analysis = $self->get_id_analysis($read);
     my $lane_summary_by_read = $lane_summary_db->{$read};

     foreach my $lane (keys %{$lane_summary_by_read}){

       my $lane_summary_by_read_lane = $lane_summary_by_read->{$lane};

       $lane_summary_by_read_lane->{id_run} = $self->id_run();
       $lane_summary_by_read_lane->{end}    = $read;
       $lane_summary_by_read_lane->{position} = $lane;
       $lane_summary_by_read_lane->{id_analysis} = $id_analysis;

       $self->schema->resultset('AnalysisLane')->update_or_create(
                                         $lane_summary_by_read_lane
                                      );
     }
  }
  return 1;
}

sub _process_lane_result_summary_by_read{
  my ($self, $read, $lane_summary_db) = @_;

  my $read_number = $read->getElementsByTagName('readNumber')->[0]->textContent();

  $read_number = $self->transfer_read_number($read_number);

  $self->mlog("Processing read $read_number");

  my $lane_result_summary_by_read_lane = $read->getElementsByTagName('Lane');
  foreach my $lane (@{$lane_result_summary_by_read_lane}){
     $self->_process_lane_result_summary_by_read_lane($lane, $read_number, $lane_summary_db);
  }
  return 1;
}


sub _process_lane_result_summary_by_read_lane{
  my ( $self, $lane, $read_number, $lane_summary_db ) = @_;

  my $lane_number = $lane->getElementsByTagName('laneNumber')->[0]->textContent();
  my $lane_yield_node = $lane->getElementsByTagName('laneYield')->[0];
  if( ! $lane_yield_node ){
     $self->mlog("There are no lane yield available for lane $lane_number read $read_number");
     return 1;
  }
  my $lane_yield =  $lane_yield_node->textContent();

  $self->mlog("Processing read $read_number lane $lane_number");

  $lane_summary_db->{$read_number}->{$lane_number}->{lane_yield} = $lane_yield;

  foreach my $field ( keys %{ $LANE_SUMMARY_FIELDS_TO_LOAD } ){

    my $db_field = $LANE_SUMMARY_FIELDS_TO_LOAD->{$field};
    my $element = $lane->getElementsByTagName($field)->[0];
    if($element){
      my $mean  = $element->getElementsByTagName('mean')->[0]->textContent();
      my $stdev = $element->getElementsByTagName('stdev')->[0]->textContent();
      $lane_summary_db->{$read_number}->{$lane_number}->{$db_field} = $mean;
      $lane_summary_db->{$read_number}->{$lane_number}->{$db_field.q{_err}} = $stdev;
    }
  }
  return 1;
}

sub _process_expanded_lane_summary_by_read{
  my ($self, $read, $lane_summary_db) = @_;

  my $read_number = $read->getElementsByTagName('readNumber')->[0]->textContent();

  $read_number = $self->transfer_read_number($read_number);

  $self->mlog("Processing read $read_number");

  my $expanded_lane_summary_by_read_lane = $read->getElementsByTagName('Lane');
  foreach my $lane (@{$expanded_lane_summary_by_read_lane}){
     $self->_process_expanded_lane_summary_by_read_lane($lane, $read_number, $lane_summary_db);
  }
  return 1;
}

sub _process_expanded_lane_summary_by_read_lane{
  my ( $self, $lane, $read_number, $lane_summary_db ) = @_;

  my $lane_number = $lane->getElementsByTagName('laneNumber')->[0]->textContent();

  $self->mlog("Processing read $read_number lane $lane_number");

  my $expanded_lane_summary_by_read_lane = {};

  foreach my $field ( keys %{ $LANE_EXPANDED_SUMMARY_FIELDS_WITH_ERROR_TO_LOAD } ){

    my $db_field = $LANE_EXPANDED_SUMMARY_FIELDS_WITH_ERROR_TO_LOAD->{$field};
    my $element = $lane->getElementsByTagName($field)->[0];
    if($element){
      my $mean  = $element->getElementsByTagName('mean')->[0]->textContent();
      my $stdev = $element->getElementsByTagName('stdev')->[0]->textContent();
      $lane_summary_db->{$read_number}->{$lane_number}->{$db_field} = $mean;
      $lane_summary_db->{$read_number}->{$lane_number}->{$db_field.q{_err}} = $stdev;
    }
  }

  foreach my $field ( keys %{ $LANE_EXPANDED_SUMMARY_FIELDS_NO_ERR_TO_LOAD } ){

    my $db_field = $LANE_EXPANDED_SUMMARY_FIELDS_NO_ERR_TO_LOAD->{$field};
    my $element = $lane->getElementsByTagName($field)->[0];
    if($element){
      my $mean  = $element->getElementsByTagName('mean')->[0]->textContent();
      $lane_summary_db->{$read_number}->{$lane_number}->{$db_field} = $mean;
    }
  }

  foreach my $field ( keys %{ $LANE_EXPANDED_SUMMARY_FIELDS_TO_LOAD } ){

    my $db_field = $LANE_EXPANDED_SUMMARY_FIELDS_TO_LOAD->{$field};
    my $element = $lane->getElementsByTagName($field)->[0];
    if($element){
      my $value  = $element->textContent();
      $lane_summary_db->{$read_number}->{$lane_number}->{$db_field} = $value;
    }
  }
  return 1;
}

sub _prosess_tile_result_by_lane{
  my ($self, $lane) = @_;

  my $lane_number = $lane->getElementsByTagName('laneNumber')->[0]->textContent();
  $self->mlog(qq{Processing tile result by lane data for lane $lane_number...});

  my $read_list = $lane->getElementsByTagName('Read');
  foreach my $read (@{$read_list}){
     $self->_process_tile_result_by_lane_read( $lane_number, $read );
  }
  return 1;
}

sub _process_tile_result_by_lane_read{
  my ($self, $lane_number, $read) = @_;

  my $read_number = $read->getElementsByTagName('readNumber')->[0]->textContent();

  $read_number = $self->transfer_read_number($read_number);

  $self->mlog(qq{Processing read $read_number...});

  my $tile_list = $read->getElementsByTagName('Tile');

  foreach my $tile (@{$tile_list}){
     $self->_process_tile_result_by_lane_read_tile($lane_number, $read_number, $tile);
  }
  return 1;
}

sub _process_tile_result_by_lane_read_tile{
  my ($self, $lane_number, $read_number, $tile) = @_;

  my $tile_number = $tile->getElementsByTagName('tileNumber')->[0]->textContent();
  $tile_number += 0;

  my $id_run_tile = $self->get_id_run_tile($lane_number, $read_number, $tile_number);

  my $lane_qc_db ={end         => $read_number,
                   id_run_tile => $id_run_tile,
                  };

  foreach my $field (keys %{$LANE_QC_FIELDS_TO_LOAD}){
    my $value = $tile->getElementsByTagName($field)->[0]->textContent();
    if ($field eq 'signal20AsPctOf1' && (uc $value eq 'N/A')) {
      # N/A is legit, before sql ctrict mode was enabled, zeros were pushed implicitly
      $value = 0; # would be better to push NULL, but for the fear of any calculation performed
                  # when rendering, settled on 0
    }
    $lane_qc_db->{$LANE_QC_FIELDS_TO_LOAD->{$field}} = $value;
  }

  $self->schema->resultset('LaneQc')->update_or_create(
                                         $lane_qc_db
                                      );
  return 1;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Carp

=item English -no_match_vars

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2009 Guoying Qi (gq1@sanger.ac.uk)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
