package npg_qc::autoqc::role::tag_decode_stats;

use Moose::Role;
use Carp;
use Readonly;
use PDL::Lite;
use PDL::Core qw(pdl);

our $VERSION = '0';

Readonly::Scalar our $PERCENT => 100;
Readonly::Scalar our $DECODING_PASS_PERCENT => 80;
Readonly::Scalar our $EXPECTED_NUMBER_OF_PARTS => 4;
Readonly::Scalar our $IGNORE_TAG_INDEX         => 168;

sub parsing_output_string {
  my ( $self, $stats_output ) = @_;

  my @parts = split /\n\n/mxs, $stats_output;

  if ( scalar @parts != $EXPECTED_NUMBER_OF_PARTS ) {
    carp "Possible Problems with tag decoding output format:\n$stats_output\n\tNumber of parts obtained: " . (scalar @parts) . "\n\tNumber of parts expected: $EXPECTED_NUMBER_OF_PARTS\n\t\tWill attempt to get any possible data.";
  }

  my ( undef, $error_part, undef, $distribution_part ) = @parts;

  if ( $error_part ) {
    my @errors = split /\n/mxs, $error_part;
    shift @errors;
    shift @errors;
    foreach my $error (@errors){

      my ($head, $tail) = split /:/mxs, $error;
      my ($num_errors) = $head =~ /(\d+)/mxs;

      if(! defined $num_errors) {
        $num_errors = q{no_match};
      }

      my ($count_all, $count_good) = $tail =~ /(\d+)\s+\(.*\)\s+(\d+)/mxs;
      $self->errors_all->{$num_errors} = $count_all;
      $self->errors_good->{$num_errors} = $count_good;
    }

  } else {
    $self->pass(0);
  }

  if ( $distribution_part ) {
    my @distributions = split /\n/mxs, $distribution_part;

    shift @distributions;
    shift @distributions;
    foreach my $distribution ( @distributions ) {

      my ($tag, $code, $count_all, $count_good) =
      $distribution =~ /^([ACTG]+)[ ](\d+)\s+(\d+)[ ][(].*[)]\s+(\d+)/mxs;
      $self->tag_code->{$code} = $tag;
      $self->distribution_all->{$code} = $count_all;
      $self->distribution_good->{$code} = $count_good;

    }

    $self->check_pass();
  } else {
    $self->pass(0);
  }

  return 1;
}

sub decoding_perc_all{
  my $self = shift;

  my $errors_perc_all = $self->errors_perc_all();

  if(! defined $errors_perc_all){
    return;
  }

  my $perc_no_match = $errors_perc_all->{q{no_match}};

  if(! defined $perc_no_match ){
    return;
  }

  return $PERCENT - $perc_no_match;
}

sub decoding_perc_good{
  my $self = shift;
  my $errors_perc_good = $self->errors_perc_good();

  if(! defined $errors_perc_good){
    return;
  }

  my $perc_no_match = $errors_perc_good->{q{no_match}};

  if(! defined $perc_no_match ){
    return;
  }

  return $PERCENT - $perc_no_match;
}

sub check_pass{
  my $self = shift;

  my $decoding_perc_all = $self->decoding_perc_all;
  my $decoding_perc_good = $self->decoding_perc_good;

  if(defined $decoding_perc_all && $decoding_perc_all >= $DECODING_PASS_PERCENT && defined $decoding_perc_good && $decoding_perc_good >= $DECODING_PASS_PERCENT){
    $self->pass(1);
  }else{
    $self->pass(0);
  }

  return $self->pass;
}

sub distribution_perc_all{
  my $self = shift;
  return $self->_percentage_from_count($self->distribution_all());
}

sub distribution_perc_good{
  my $self = shift;
  return $self->_percentage_from_count($self->distribution_good());
}

sub errors_perc_all{
  my $self = shift;
  return $self->_percentage_from_count($self->errors_all());
}

sub errors_perc_good{
  my $self = shift;
  return $self->_percentage_from_count($self->errors_good());
}

sub _percentage_from_count {
  my ($self, $count_hashref) = @_;

  if(! defined $count_hashref ){
    return;
  }

  my $percentage_hashref = {};

  my $total = 0;
  foreach my $count (values %{$count_hashref}){
    $total += $count;
  }

  if($total == 0 ){
    return;
  }

  foreach my $code (keys %{$count_hashref}){
    $percentage_hashref->{$code} = sprintf '%.2f', $count_hashref->{$code} * $PERCENT/$total;
  }

  return $percentage_hashref;
}

sub variance_coeff {
  my ($self, $dist) = @_;

  if (!$dist) { $dist = q[good]; }
  if ($dist !~ /good|all/smx) {
      croak qq[Unexpected distribution type $dist; should be 'good' or 'all'.];
  }
  my $name = q[distribution_] . $dist;
  my @values = ();
  foreach my $key (keys %{$self->$name}) {
    if ($key != $IGNORE_TAG_INDEX) {
      push @values, $self->$name->{$key};
    }
  }
  if (!@values) { return; }
  my $p = (pdl \@values);
  my ($mean,$prms,$median,$min,$max,$adev,$rms) = PDL::Primitive::stats($p);
  my $cv = $rms/$mean * $PERCENT;
  if ($mean->sclr == 0) {
    return 0;
  }
  return $cv->sclr;
}

sub has_spiked_phix_tag {
  my ($self) = @_;
  return exists $self->distribution_good->{$IGNORE_TAG_INDEX} ? 1 : 0;
}

no Moose;

1;

__END__


=head1 NAME

    npg_qc::autoqc::role::tag_decode_stats

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=head2 parsing_output_string - parsing the tag decode output and store them in result object

=head2 decoding_perc_all

=head2 decoding_perc_good

=head2 check_pass

=head2 distribution_perc_all

=head2 distribution_perc_good

=head2 errors_perc_all

=head2 errors_perc_good

=head2 variance_coeff

=head2 has_spiked_phix_tag

=head2 BEGIN

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item npg_qc::autoqc::role::result

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi E<lt>gq1@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 GRL

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
