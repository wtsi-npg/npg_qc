package npg_qc::illumina::interop::parser;

use Moose;
use MooseX::StrictConstructor;
use Carp;
use English qw(-no_match_vars);
use namespace::autoclean;
use List::Util qw(sum);
use PDL::Lite;
use PDL::Core qw(pdl);
use Try::Tiny;
use Readonly;

extends qw(npg_tracking::illumina::runfolder);

our $VERSION = '0';

Readonly::Scalar our $PERCENT => 100;

# keys used in hash and corresponding codes in tile metrics interop file
# (assumes no more than 4 reads)
Readonly::Scalar my $TILE_METRICS_INTEROP_CODES => {'cluster_density'    => 100,
                                                    'cluster_density_pf' => 101,
                                                    'cluster_count'      => 102,
                                                    'cluster_count_pf'   => 103,
                                                    'aligned_read1'      => 300,
                                                    'aligned_read4'      => 303,
                                                    'version3 tile'      => ord('t'),
                                                    'version3 read'      => ord('r'),
                                                   };

has 'interop_path' => (
  isa        => 'Str',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
);
sub _build_interop_path {
  my $self = shift;
  my $interop_dir = join q[/], $self->runfolder_path(), 'InterOp';
  (-d $interop_dir) or croak
    qq(InterOp files directory $interop_dir does not exist);
  return $interop_dir;
}

has 'p4s1_i2b_first_tile' => ( isa        => q{Maybe[Int]},
                               is         => 'ro',
                               required   => 0,
                               lazy_build => 1,
                       );

has 'p4s1_i2b_tile_limit' => ( isa        => q{Maybe[Int]},
                               is         => 'ro',
                               required   => 0,
                               lazy_build => 1,
                       );

sub parse {
  my $self = shift;

  my $input_files = $self->_input_files;

  my $tile_limits;
  if(defined $self->p4s1_i2b_first_tile or defined $self->p4s1_i2b_tile_limit) {
    $tile_limits = { first_tile => $self->p4s1_i2b_first_tile, tile_limit => $self->p4s1_i2b_tile_limit};
  }

  # there should always be one input file, the TileMetrics interop file
  my ($lane_metrics, $cluster_count) = $self->_parse_tile_metrics($input_files->[0], $tile_limits);

  # the ExtendedTileMetrics interop file is optional
  if ( scalar(@{$input_files}) > 1 ) {
    $self->_parse_extended_tile_metrics($input_files->[1], $lane_metrics, $cluster_count, $tile_limits);
  }

  return $lane_metrics;
}

Readonly::Scalar my $SKIP_TILE => 1;
Readonly::Scalar my $DONT_SKIP_TILE => 0;

sub _skip_tile {
  my ($tile, $tile_limits) = @_;

  if(not defined $tile_limits) { return $DONT_SKIP_TILE }

  if(defined $tile_limits->{first_tile} and $tile < $tile_limits->{first_tile}) { return $SKIP_TILE; }

  if(not defined $tile_limits->{tile_limit} or ($tile_limits->{tile_limit} <= 0)) { return $SKIP_TILE; }

  $tile_limits->{tile_limit}--;

  return $DONT_SKIP_TILE;
}

sub _parse_tile_metrics { ##no critic (Subroutines::ProhibitExcessComplexity)
  my ($self, $interop, $tile_limits) = @_;

  my %lane_metrics  = ();
  my %cluster_count = ();

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

  my %tile_metrics = ();

  # TO DO: I think the mean/stdev values in SAV excludes tiles where no reads pass PF
  # if we want to get exactly the same values we will have to exclude such tiles

  ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
  if( $version == 2) {
    my $template = 'v3f'; # three 2-byte integers and one 4-byte float
    while ($fh->read($data, $length)) {
      my ($lane,$tile,$code,$value) = unpack $template, $data;

      if(_skip_tile($tile, $tile_limits)) { next }

      ## no critic (ControlStructures::ProhibitCascadingIfElse)
      if( $code == $TILE_METRICS_INTEROP_CODES->{'cluster_density'} ){
        $tile_metrics{$lane}->{'cluster_density'}->{$tile} = $value;
      }elsif( $code == $TILE_METRICS_INTEROP_CODES->{'cluster_density_pf'} ){
        $tile_metrics{$lane}->{'cluster_density_pf'}->{$tile} = $value;
      }elsif( $code == $TILE_METRICS_INTEROP_CODES->{'cluster_count'} ){
        $tile_metrics{$lane}->{'cluster_count'}->{$tile} = $value;
        # keep a copy of the cluster_count per tile to convert occupied from a count to a percentage;
        $cluster_count{$lane}->{$tile} = $value;
      }elsif( $code == $TILE_METRICS_INTEROP_CODES->{'cluster_count_pf'} ){
        $tile_metrics{$lane}->{'cluster_count_pf'}->{$tile} = $value;
        # calculate a cluster pf
        if( exists($cluster_count{$lane}->{$tile}) ){
          if( $cluster_count{$lane}->{$tile} == 0 ){
            croak qq{cluster_count for lane $lane tile $tile is zero};
          }
          # convert count to a percentage
          my $cluster_pf = $PERCENT * $tile_metrics{$lane}->{'cluster_count_pf'}->{$tile} / $cluster_count{$lane}->{$tile};
          $tile_metrics{$lane}->{'cluster_pf'}->{$tile} = $cluster_pf;
        } else {
          croak qq{No cluster_count for lane $lane tile $tile};
        }
      }elsif( ($code >= $TILE_METRICS_INTEROP_CODES->{'aligned_read1'}) && ($code <= $TILE_METRICS_INTEROP_CODES->{'aligned_read4'}) ){
        my $read = $code - $TILE_METRICS_INTEROP_CODES->{'aligned_read1'} + 1;
        $tile_metrics{$lane}->{'aligned'}->{$read}->{$tile} = $value;
      }
      ## use critic
    }
  } elsif( $version == 3) {
    $fh->read($data, 4) or
      croak qq{Couldn't read area in interop file $interop, error $ERRNO};
    my $area = unpack 'f', $data;
    if( $area == 0.0 ) {
      croak qq{Invalid area $area in interop file $interop};
    }
    while ($fh->read($data, $length)) {
      my $template = 'vVc'; # one 2-byte integer, one 4-byte integer and one 1-byte char
      my ($lane,$tile,$code) = unpack $template, $data;

      if(_skip_tile($tile, $tile_limits)) { next }

      if( $code == $TILE_METRICS_INTEROP_CODES->{'version3 tile'} ){
        $data = substr $data, 7;
        $template = 'f2'; # two 4-byte floats
        my ($cluster_count, $cluster_count_pf) = unpack $template, $data;
        $tile_metrics{$lane}->{'cluster_count'}->{$tile} = $cluster_count;
        $tile_metrics{$lane}->{'cluster_count_pf'}->{$tile} = $cluster_count_pf;
        my $cluster_density = $cluster_count / $area;
        my $cluster_density_pf = $cluster_count_pf / $area;
        $tile_metrics{$lane}->{'cluster_density'}->{$tile} = $cluster_density;
        $tile_metrics{$lane}->{'cluster_density_pf'}->{$tile} = $cluster_density_pf;
        # convert count to a percentage
        my $cluster_pf = $PERCENT * $cluster_count_pf / $cluster_count;
        $tile_metrics{$lane}->{'cluster_pf'}->{$tile} = $cluster_pf;
        # keep a copy of the cluster_count per tile to convert occupied from a count to a percentage;
        $cluster_count{$lane}->{$tile} = $cluster_count;
      } elsif ( $code == $TILE_METRICS_INTEROP_CODES->{'version3 read'} ){
        $data = substr $data, 7;
        $template = 'Vf'; # one 4-byte int and one 4-byte float
        my ($read, $aligned) = unpack $template, $data;
        if( $aligned ne q[NaN] ){ # skip NaNs
          $tile_metrics{$lane}->{'aligned'}->{$read}->{$tile} = $aligned;
        }
      }
    }
  } else {
    croak qq{Unknown version $version in interop file $interop};
  }

  $fh->close() or croak qq{Couldn't close interop file $interop, error $ERRNO};

  my $lanes = scalar keys %tile_metrics;
  if( $lanes == 0){
    $self->mlog( qq{No data in $interop} );
    return;
  }

  # calc lane total
  foreach my $lane (keys %tile_metrics){
    for my $code (keys %{$tile_metrics{$lane}}) {
      $code =~ m/^cluster_count/smx or next;
      my @values = (values %{$tile_metrics{$lane}->{$code}});
      my $total = sum @values;
      $lane_metrics{$code.'_total'}->{$lane} = $total;
    }
  }

  # calc lane mean and stdev
  foreach my $lane (keys %tile_metrics){
    for my $code (keys %{$tile_metrics{$lane}}) {
      if( $code eq 'aligned' ){
        for my $read (keys %{$tile_metrics{$lane}->{$code}}) {
          my @values = (values %{$tile_metrics{$lane}->{$code}->{$read}});
          my $p = (pdl \@values)->qsort();
          my ($mean,$prms,$median,$min,$max,$adev,$rms) = PDL::Primitive::stats($p);
          $lane_metrics{$code.'_mean'}->{$lane}->{$read} = $mean->sclr;
          $lane_metrics{$code.'_stdev'}->{$lane}->{$read} = $prms->sclr;
        }
      } else {
        my @values = (values %{$tile_metrics{$lane}->{$code}});
        my $p = (pdl \@values)->qsort();
        my ($mean,$prms,$median,$min,$max,$adev,$rms) = PDL::Primitive::stats($p);
        $lane_metrics{$code.'_mean'}->{$lane} = $mean->sclr;
        $lane_metrics{$code.'_stdev'}->{$lane} = $prms->sclr;
      }
    }
  }

  return (\%lane_metrics, \%cluster_count);
}

sub _parse_extended_tile_metrics {
  my ($self, $interop, $lane_metrics, $cluster_count, $tile_limits) = @_;

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

  my %tile_metrics = ();

  # TO DO: I think the mean/stdev values in SAV excludes tiles where no reads pass PF
  # if we want to get exactly the same values we will have to exclude such tiles

  ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
  if( $version == 2 || $version == 3 ) {
    while ($fh->read($data, $length)) {
      my $template = 'vVf'; # one 2-byte integer, one 4-byte integer and one 4-byte float
      # N.B. In version 3 there are two additional 4-byte floats,
      # the upper left and right fiducial locations but we don't use these
      my ($lane,$tile,$occupied) = unpack $template, $data;

      if(_skip_tile($tile, $tile_limits)) { next }

      if( exists($cluster_count->{$lane}->{$tile}) ){
        if( $cluster_count->{$lane}->{$tile} == 0 ){
          croak qq{cluster_count for lane $lane tile $tile is zero};
        }
        # convert count to a percentage
        $occupied = $PERCENT * $occupied / $cluster_count->{$lane}->{$tile};
        $tile_metrics{$lane}->{'occupied'}->{$tile} = $occupied;
      } else {
        croak qq{No cluster_count for lane $lane tile $tile};
      }
    }
  } else {
    croak qq{Unknown version $version in interop file $interop};
  }

  $fh->close() or croak qq{Couldn't close interop file $interop, error $ERRNO};

  my $lanes = scalar keys %tile_metrics;
  if( $lanes == 0){
    $self->mlog( qq{No data in $interop} );
    return;
  }

  # calc lane stats
  foreach my $lane (keys %tile_metrics){
    my $code = 'occupied';
    my @values = (values %{$tile_metrics{$lane}->{$code}});
    my $p = (pdl \@values)->qsort();
    my ($mean,$prms,$median,$min,$max,$adev,$rms) = PDL::Primitive::stats($p);
    $lane_metrics->{$code.'_mean'}->{$lane} = $mean->sclr;
    $lane_metrics->{$code.'_stdev'}->{$lane} = $prms->sclr;
  }

  return;
}

sub _input_files {
  my $self = shift;

  my @files = ();

  my $tile_metrics_interop_file =
    join q[/], $self->interop_path, 'TileMetricsOut.bin';
  (-e $tile_metrics_interop_file ) or croak
    qq($tile_metrics_interop_file does not exist);
  push @files, $tile_metrics_interop_file;

  my $extended_tile_metrics_interop_file =
    join q[/], $self->interop_path, 'ExtendedTileMetricsOut.bin';
  if ( ! -e $extended_tile_metrics_interop_file ) {
    carp qq($extended_tile_metrics_interop_file does not exist);
  } else {
    push @files, $extended_tile_metrics_interop_file;
  }

  return \@files;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

npg_qc::illumina::interop::parser

=head1 SYNOPSIS

  my $data;
  $data = npg_qc::illumina::interop::parser->new()->parse();
  $data = npg_qc::illumina::interop::parser->new(
    runfolder_path => 'dir1')->parse();
  $data = npg_qc::illumina::interop::parser->new(
    interop_path => 'dir2')->parse();

=head1 DESCRIPTION

Parses TileMetricsOut.bin IIllumina InterOp file and, if available,
ExtendedTileMetricsOut.bin file to get precise cluster count values
and some other statistics.

Inherits from npg_tracking::illumina::runfolder in order to be able
to find run folder location. runfolder_path attribute can be supplied
by the caller to set the run folder path. The InterOp files are expected
to be found in the InterOp directory in the run folder. It is possible
to set the path of the InterOp directly by setting interop_path
attribute.

=head1 SUBROUTINES/METHODS

=head2 interop_path

A directory path where InterOp files are, a lazy-built atribute.

=head2 parse

Parses TileMetricsOut.bin IIllumina InterOp file and, if available,
ExtendedTileMetricsOut.bin file to get precise cluster count values
and some other lane statistics. The results are returned as a hash
reference.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item Carp

=item English

=item Readonly

=item List::Util

=item PDL::Lite

=item PDL::Core

=item Try::Tiny

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Steven Leonard E<lt>srl@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2019 GRL

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
