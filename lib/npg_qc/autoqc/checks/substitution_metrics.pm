
package npg_qc::autoqc::checks::substitution_metrics;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Carp;
use File::Basename;
use File::Spec::Functions qw(catfile);
use Perl6::Slurp;
use Readonly;

extends qw( npg_qc::autoqc::checks::check );
with    qw( npg_tracking::glossary::subset );

our $VERSION = '0';


Readonly::Hash my %METRICS_FIELD_MAPPING => {
   'TiTv_class' => 'titv_class',
   'TiTv_meCA'  => 'titv_mean_ca',
   'fracH'      => 'frac_sub_hq',
   'oxoGHbias'  => 'oxog_bias',
   'symGT_CA'   => 'sym_gt_ca',
   'sym_ct_ga'  => 'sym_ct_ga',
   'sym_ag_tc'  => 'sym_ag_tc',
   'cvTi'       => 'cv_ti',
   'GT_Ti'      => 'gt_ti',
   'GT_meTi'    => 'gt_mean_ti',
   'art_oxH'    => 'ctoa_oxh',
   'predict'    => 'ctoa_art_predicted_level'
};

Readonly::Scalar our $EXT      => q[cram];
Readonly::Scalar our $FILE_EXT => q[substitution_metrics.txt];

has '+subset' => ( isa => 'Str', );

has '+file_type' => (default => $EXT,);

has '_file_path_root' => ( isa        => 'Str',
                           is         => 'ro',
                           lazy_build => 1,);

sub _build__file_path_root {
  my $self = shift;
  my $path;
  if ($self->has_filename_root && $self->has_qc_in) {
    $path = catfile $self->qc_in, $self->filename_root;
  } else {
    ($path) = $self->input_files->[0] =~ /\A(.+)\.[[:lower:]]+\Z/smx;
  }
  return $path;
}

has [ qw/ substitution_metrics_file / ] => (
    isa        => 'NpgTrackingReadableFile',
    is         => 'ro',
    required   => 0,
    lazy_build => 1,
    );

has '+substitution_metrics_file' => (init_arg   => undef);

sub _build_substitution_metrics_file {
  my $self = shift;
  my $metrics_file = join q[.], $self->_file_path_root, $FILE_EXT;
  return $metrics_file;
}


override 'execute' => sub {
  my $self = shift;

  super();

  if( $self->substitution_metrics_file && -f $self->substitution_metrics_file ) {
    $self->_parse_substitution_metrics_file();
  } else {
    croak 'No input metrics file found';
  }

  return;
};

sub _parse_substitution_metrics_file {
  my $self = shift;

  my @file_contents = slurp ( $self->substitution_metrics_file,
                              { chomp => 1, irs => qr/\n+/smx } );

  shift @file_contents; # skip header line
  foreach my $line (@file_contents){
    my @metrics  = split /\s+/mxs, $line;
    if( $METRICS_FIELD_MAPPING{$metrics[0]} ) {
      $self->result()->${\$METRICS_FIELD_MAPPING{$metrics[0]}}( $metrics[1] );
    }
  }

  return;
}



__PACKAGE__->meta->make_immutable();

1;

__END__


=head1 NAME

npg_qc::autoqc::checks::substitution_metrics - primarily metrics 
related to C2A 

=head1 SYNOPSIS

    use npg_qc::autoqc::checks::substitution_metrics;

=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=head2 subset

  An optional subset, see npg_tracking::glossary::subset for details.

=head2 substitution_metrics_file

=head2 execute


=head2 new

    Moose-based.

=head1 DIAGNOSTICS

    None.

=head1 CONFIGURATION AND ENVIRONMENT

=head1 INCOMPATIBILITIES

    None known.

=head1 BUGS AND LIMITATIONS

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item Carp

=item File::Basename

=item Perl6::Slurp

=item Readonly

=back

=head1 AUTHOR

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2022 GRL

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
