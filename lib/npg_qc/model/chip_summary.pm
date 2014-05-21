#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-06-25
# Last Modified: $Date: 2012-08-09 12:31:39 +0100 (Thu, 09 Aug 2012) $
# Id:            $Id: chip_summary.pm 15982 2012-08-09 11:31:39Z mg8 $
# Source:        $Source: /repos/cvs/webcore/SHARED_docs/cgi-bin/docrep,v $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/model/chip_summary.pm $
#

package npg_qc::model::chip_summary;
use strict;
use warnings;
use base qw(npg_qc::model);
use English qw{-no_match_vars};
use Carp;

our $VERSION = '0';

__PACKAGE__->mk_accessors(__PACKAGE__->fields());

sub fields {
  return qw(
            id_chip_summary
            id_run
            paired
            chip_id
            clusters
            clusters_pf
            yield_kb
            machine
          );
}

sub init {
  my $self = shift;
  if($self->{id_run} && !$self->{id_chip_summary}) {
    my $query = q(SELECT id_chip_summary
                  FROM   chip_summary
                  WHERE  id_run = ?);
    my $ref   = [];
    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->id_run());
      1;
    } or do {
      carp $EVAL_ERROR;
      return;
    };
    if(@{$ref}) {
      $self->{'id_chip_summary'} = $ref->[0]->[0];
    }
  }
  return 1;
}

sub cycle_count {
  my $self = shift;

  if (!$self->{cycle_count}) {

    $self->{cycle_count} = $self->get_cycle_count_from_recipe($self->{id_run}, 1);
  }

  return $self->{cycle_count};
}

sub cycle_count_2nd_end {
  my $self = shift;

  if (!$self->{cycle_count_2nd_end}) {

    $self->{cycle_count_2nd_end} = $self->get_cycle_count_from_recipe($self->{id_run}, 2);
  }

  return $self->{cycle_count_2nd_end};
}

sub read_length {
  my $self = shift;

  my $read_length1 = $self->get_read_length_from_recipe($self->{id_run}, 1);
  my $return_value = $read_length1;
  if($self->paired()){
    my $read_length2 = $self->get_read_length_from_recipe($self->{id_run}, 2);
    if($read_length2){
     $return_value .=q{, }.$read_length2;
    }
  }

  return $return_value;
}

sub qcal_by_lane {
  my $self = shift;

  my $query = q{SELECT position, section, twenty, twentyfive, thirty FROM fastqcheck 
                  WHERE id_run = ? AND section != 'index' AND tag_index=-1 AND split='none'};

  my $sth = $self->util->dbh()->prepare($query);
  $sth->execute($self->id_run());

  my $qcal_by_lanes = {};
  while(my @row = $sth->fetchrow_array()) {
    my $lane = shift @row;
    my $end = shift @row;
    $end = $end eq 'forward' ? 1 : 2;
    @row = map{defined $_ ? $_ : q[-]} @row; # intweb version of template toolkit does not cope with undef values
    $qcal_by_lanes->{$lane}->{q20}->{$end} =  shift @row;
    $qcal_by_lanes->{$lane}->{q25}->{$end} =  shift @row;
    $qcal_by_lanes->{$lane}->{q30}->{$end} =  shift @row;
  }

  return $qcal_by_lanes;
}

sub qcal_total {
  my $self = shift;

  my $query = q{SELECT SUM(IFNULL(twenty, 0)), SUM(IFNULL(twentyfive, 0)), SUM(IFNULL(thirty, 0))  FROM fastqcheck WHERE id_run = ? AND section != 'index' AND tag_index=-1 AND split='none'};
  my $dbh = $self->util->dbh();
  my $sth = $dbh->prepare($query);
  $sth->execute($self->id_run());
  my @a = $sth->fetchrow_array();
  return map{defined $_ ? $_ : q[-]} @a; # intweb version of template toolkit does not cope with undef values
}

1;
__END__
=head1 NAME

npg_qc::model::chip_summary

=head1 VERSION

$Revision: 15982 $

=head1 SYNOPSIS

  my $oChipSummary = npg_qc::model::chip_summary->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - return array of fields, first of which is the primary key

  my $aFields = $oChipSummary->fields();

=head2 init - on creation, goes to see if a summary already exists for the id_run, if provided, and creates object with it if it is

=head2 cycle_count - returns the cycle count for the run, for the first end run if paired

  my $iCycleCount = $oChipSummary->cycle_count();
  
=head2 cycle_count_2nd_end - returns the cycle count for the second end run if paired

=head2 qcal_total - returns q20, q25 and q30 for this run summed up by lane

  my $oQCal = $oChipSummary->qcal_total();
  
=head2 qcal_by_lane - return all qcal values by lane for this run

=head2 read_length - returns the read length obtained

  my $iReadLength = $oChipSummary->read_length();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::model

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown, E<lt>ajb@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Andy Brown

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
