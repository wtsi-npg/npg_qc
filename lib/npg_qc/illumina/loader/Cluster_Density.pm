package npg_qc::illumina::loader::Cluster_Density;

use Moose;
use namespace::autoclean;
use Carp;
use English qw{-no_match_vars};
use Try::Tiny;
use Readonly;

extends 'npg_qc::illumina::loader::base';

our $VERSION = '0';

#keys used in hash and corresponding codes in tile metrics interop file
Readonly::Scalar our $TILE_METRICS_INTEROP_CODES => {'cluster density'    => 100,
                                                     'cluster density pf' => 101,
                                                     'cluster count'      => 102,
                                                     'cluster count pf'   => 103,
                                                     'version3_cluster_counts' => ord('t'),
                                                     };

Readonly::Array my @TILE_METRICS_INTEROP_FILE => qw/InterOp TileMetricsOut.bin/;
Readonly::Array my @TILE_METRICS_PF_CYCLE_INTEROP_FILE => qw/InterOp C25.1 TileMetricsOut.bin/;

sub run_all {
  my $self = shift;

  my %rfolders = %{$self->runfolder_list_todo()};
  foreach my $id_run (sort { $a <=> $b } keys %rfolders) {
    try {
      $self->mlog(qq{Loading cluster density data for run $id_run});
      my $interop_file = join q[/], $rfolders{$id_run}, @TILE_METRICS_INTEROP_FILE;
      if ( ! -e $interop_file ) {
        $self->mlog(qq{Couldn't find interop file $interop_file, looking in pf_cycle sub-directory});
        # look for one in the PF_CYCLE sub-directory
        $interop_file = join q[/], $rfolders{$id_run}, @TILE_METRICS_PF_CYCLE_INTEROP_FILE;
      }
      $self->_save_to_db($id_run, $self->_parse_interop($interop_file));
    } catch {
      my $error = $_;
      if( $error =~ /No\ such\ file\ or\ directory/mxs){
        $self->mlog( qq{No cluster density file available for run $id_run} );
      }else{
        croak $error;
      }
    };
  }
  return;
}

sub _build_runlist_db {
  return;
}

sub _parse_interop {
  my ($self, $interop) = @_;

  my $cluster_density_by_lane = {};

  my $version;
  my $length;
  my $data;

  ## no critic (InputOutput::RequireBriefOpen)
  open my $fh, q{<}, $interop or croak qq{Couldn't open interop file $interop, error $ERRNO};
  binmode $fh, ':raw';

  $fh->read($data, 1) or croak qq{Couldn't read file version in interop file $interop, error $ERRNO};
  $version = unpack 'C', $data;

  $fh->read($data, 1) or croak qq{Couldn't read record length in interop file $interop, error $ERRNO};
  $length = unpack 'C', $data;

  my $tile_metrics = {};

  ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
  if( $version == 3) {
    $fh->read($data, 4) or
      croak qq{Couldn't read area in interop file $interop, error $ERRNO};
    my $area = unpack 'f', $data;
    if( $area == 0.0 ) {
      croak qq{Invalid area $area in interop file $interop};
    }
    while ($fh->read($data, $length)) {
      my $template = 'vVc'; # one 2-byte integer, one 4-byte integer and one 1-byte char
      my ($lane,$tile,$code) = unpack $template, $data;
      if( $code == $TILE_METRICS_INTEROP_CODES->{'version3_cluster_counts'} ){
        $data = substr $data, 7;
        $template = 'f2'; # two 4-byte floats
        my ($cluster_count, $cluster_count_pf) = unpack $template, $data;
        my $cluster_density = $cluster_count / $area;
        my $cluster_density_pf = $cluster_count_pf / $area;
        push @{$tile_metrics->{$lane}->{'cluster density'}}, $cluster_density;
        push @{$tile_metrics->{$lane}->{'cluster density pf'}}, $cluster_density_pf;
      }
    }
  } elsif( $version == 2) {
    my $template = 'v3f'; # three 2-byte integers and one 4-byte float
    while ($fh->read($data, $length)) {
      my ($lane,$tile,$code,$value) = unpack $template, $data;
      if( $code == $TILE_METRICS_INTEROP_CODES->{'cluster density'} ){
        push @{$tile_metrics->{$lane}->{'cluster density'}}, $value;
      }elsif( $code == $TILE_METRICS_INTEROP_CODES->{'cluster density pf'} ){
        push @{$tile_metrics->{$lane}->{'cluster density pf'}}, $value;
      }
    }
  } else {
    croak qq{Unknown version $version in interop file $interop};
  }

  $fh->close() or croak qq{Couldn't close interop file $interop, error $ERRNO};

  my $lanes = scalar keys %{$tile_metrics};
  if( $lanes == 0){
    $self->mlog( qq{No cluster density data in $interop} );
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
      $cluster_density_by_lane->{$lane}->{$code}->{'min'} = $min;
      $cluster_density_by_lane->{$lane}->{$code}->{'max'} = $max;
      $cluster_density_by_lane->{$lane}->{$code}->{'p50'} = $p50;
    }
  }

  return $cluster_density_by_lane;
}

sub _save_to_db {
  my ($self, $id_run, $cluster_density_by_lane) = @_;

  my $rs = $self->schema->resultset('ClusterDensity');
  foreach my $lane (keys %{$cluster_density_by_lane}){
    for my $code (keys %{$cluster_density_by_lane->{$lane}}) {
      my $lane_values = $cluster_density_by_lane->{$lane}->{$code};
      $lane_values->{'is_pf'}    = $code =~ /[ ]pf$/smx ? 1 : 0;
      $lane_values->{'position'} = $lane;
      $lane_values->{'id_run'}   = $id_run;
      $rs->update_or_create($lane_values);
    }
  }
  return;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

npg_qc::illumina::loader::Cluster_Density

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 run_all

loads cluster density data for all runs in runfolder_list_todo attribute

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Carp

=item English

=item Try::Tiny

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Sreven Leonard, E<lt>srl@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 GRL

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

=cut
