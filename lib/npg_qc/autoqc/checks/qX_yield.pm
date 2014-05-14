#########
# Author:        Marina Gourtovaia
# Maintainer:    $Author$
# Created:       29 July 2009
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

package npg_qc::autoqc::checks::qX_yield;

use strict;
use warnings;
use Moose;
use Readonly;
use Carp;
use English qw(-no_match_vars);
use Math::Round qw(round);

use npg_common::fastqcheck;
use npg::api::run;

extends qw(npg_qc::autoqc::checks::check);

## no critic (Documentation::RequirePodAtEnd ProhibitParensWithBuiltins)
our $VERSION   = do { my ($r) = q$Revision$ =~ /(\d+)/mxs; $r; };

=head1 NAME

npg_qc::autoqc::checks::qX_yield

=head1 VERSION

$Revision$

=head1 SYNOPSIS

Inherits from npg_qc::autoqc::checks::check. See description of attributes in the documentation for that module.
  my $check = npg_qc::autoqc::checks::qX_yield->new(path=>q[/staging/IL29/analysis/090721_IL29_3379/data], position=>1);

=head1 DESCRIPTION

A fast qX check that uses a fastqcheck file.

=head1 SUBROUTINES/METHODS

=cut


Readonly::Scalar our $Q_CUTOFF                  => 20;
Readonly::Scalar our $EXT                       => 'fastqcheck';
Readonly::Scalar our $MIN_YIELD_THRESHOLD_KB_GA    => 1_500_000;
Readonly::Scalar our $MIN_YIELD_THRESHOLD_KB_HS    => 5_000_000;
Readonly::Scalar our $DEFAULT_READ_LENGTH_GA       => 76;
Readonly::Scalar our $DEFAULT_READ_LENGTH_HS       => 75;
Readonly::Scalar our $THOUSAND                  => 1000;
Readonly::Scalar our $NA                        => -1;

has '+input_file_ext' => (default    => $EXT,);


override 'execute'            => sub  {
  my $self = shift;
  if (!super()) { return 1;}

  my @fnames = @{$self->input_files};
  my $short_fnames = $self->generate_filename_attr();

  my @thresholds = ($Q_CUTOFF);

  $self->result->threshold_quality($Q_CUTOFF);
  my $count = 0;
  my @apass = ($NA, $NA);

  foreach my $filename (@fnames) {

      my $suffix = $count + 1;
      my $filename_method = "filename$suffix";
      $self->result->$filename_method($short_fnames->[$count]);

      my $fq = npg_common::fastqcheck->new(fastqcheck_path =>$filename);
      my $values = $fq->qx_yield(\@thresholds);

      my $yield_method = "yield$suffix";
      $self->result->$yield_method(round($values->[0]/$THOUSAND));

      if (!defined $self->tag_index) {
          my $threshold = $self->_get_threshold($fq);
          if ($threshold != $NA) {
              my $threshold_yield_method = "threshold_yield$suffix";
              $self->result->$threshold_yield_method($threshold);
          } else {
              if ($self->result->$yield_method == 0 ) {
                  $threshold = 0;
              }
          }

          if ($threshold >= 0) {
              $apass[$count] = 0;
              if ($self->result->$yield_method > $threshold) {
                  $apass[$count] = 1;
              }
          }
      }
      $count++;
  }

  if (!defined $self->tag_index) {
      my $pass = $self->overall_pass(\@apass, $count);
      if ($pass != $NA) { $self->result->pass($pass); }
  }

  return 1;
};


sub _get_threshold {

  my ($self, $fq) = @_;

  ##no critic (RequireCheckingReturnValueOfEval)

  my $read_length;
  eval {
      $read_length = $fq->read_length();
  };
  if ($EVAL_ERROR || $read_length <= 0) { return $NA;}

  my $model = npg::api::run->new({ id_run => $self->id_run, })->instrument->model;
  my $threshold;

  if($model eq 'HK') {
    $threshold = $MIN_YIELD_THRESHOLD_KB_GA;
    if ($read_length != $DEFAULT_READ_LENGTH_GA) {
      $threshold = ($read_length * $threshold) / $DEFAULT_READ_LENGTH_GA;
    }
  }
  elsif($model eq 'HiSeq') {
    $threshold = $MIN_YIELD_THRESHOLD_KB_HS;
    if ($read_length != $DEFAULT_READ_LENGTH_HS) {
      $threshold = ($read_length * $threshold) / $DEFAULT_READ_LENGTH_HS;
    }
  }
  else {
    # warn - unrecognised instrument
    $self->result->comments('Unrecognised instrument model');
    $threshold = $NA;
  }

  return round($threshold);
}

no Moose;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item English -no_match_vars

=item Readonly

=item Math::Round round

=item npg_common::fastqcheck

=item npg_qc::autoqc::checks::check

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Marina Gourtovaia

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
