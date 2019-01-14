package npg_qc::autoqc::checks::qX_yield;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Readonly;
use Math::Round qw(round);
use Try::Tiny;

use npg_qc::autoqc::parse::samtools_stats;
use npg_qc::autoqc::constants qw/ $SAMTOOLS_SEC_QCFAIL_SUPPL_FILTER /;

extends qw(npg_qc::autoqc::checks::check);

## no critic (Documentation::RequirePodAtEnd ProhibitParensWithBuiltins)
our $VERSION = '0';

=head1 NAME

npg_qc::autoqc::checks::qX_yield

=head1 SYNOPSIS

Inherits from npg_qc::autoqc::checks::check.

  my $check = npg_qc::autoqc::checks::qX_yield->new(id_run => 33, position=>1, qc_in => 't');
  $check->execute();
  my $check = npg_qc::autoqc::checks::qX_yield->new(
    rpt_list => '33:1:2;33:2:2', qc_in => '/tmp', is_paired_read => 1);
  my $check = npg_qc::autoqc::checks::qX_yield->new(
    rpt_list => '33:1:2;33:2:2', is_paired_read => 1, platform_is_hiseq => 1
    qc_in => 'dir', qc_out => 'dir/qc');

=head1 DESCRIPTION

Uses samtools stats file to compute number of bases at a number of quality values (20, 30, 40).

=cut

Readonly::Array  my @QUALITY_THRESHOLDS        => (20, 30, 40);
Readonly::Scalar my $EXT                       => 'stats';
Readonly::Scalar my $MIN_YIELD_THRESHOLD_KB_HS => 5_000_000;
Readonly::Scalar my $DEFAULT_READ_LENGTH_HS    => 75;
Readonly::Scalar my $THOUSAND                  => 1000;
Readonly::Array  my @READS                     => qw/ forward reverse /;

=head1 SUBROUTINES/METHODS

=head2 file_type

Input file type extension.  Default - stats.

=cut

has '+file_type'        => (default => $EXT,);

=head2 suffix

Input file name suffix. The filter used in samtools stats command to
produce the input samtools stats file. Defaults to F0xB00.

=cut

has '+suffix' => (default => $SAMTOOLS_SEC_QCFAIL_SUPPL_FILTER,);

=head2 platform_is_hiseq

=cut

has 'platform_is_hiseq' => (isa => q[Bool], is  => q[ro],);

=head2 is_paired_read

Boolean flag indicating whether both a forward and reverse reads are present.
Defaults to true.
 
=cut

has 'is_paired_read'  => (isa       => 'Bool',
                          is        => 'ro',
                          predicate => 'has_is_paired_read',
                         );

=head2 execute

=cut

override 'execute' => sub {
  my $self = shift;

  super();

  my $stats = npg_qc::autoqc::parse::samtools_stats->new(file_path => $self->input_files->[0]);
  my @reads = @READS;
  my $is_paired_read = $self->has_is_paired_read
                       ? $self->is_paired_read
                       : $stats->has_reverse_read;

  if (!$is_paired_read) {
    pop @reads;
  }
  my $reads_length = $stats->reads_length;

  my $i = 1;
  my %indices = map { $_ => $i++ } @reads;

  my $source_file_name = $self->generate_filename_attr->[0];
  my @apass = ();
  my @thresholds = @QUALITY_THRESHOLDS;
  my $base_quality = shift @thresholds;
  $self->result->threshold_quality($base_quality);

  foreach my $read ( @reads ) {
    my $suffix = $indices{$read};
    my $filename_method = "filename$suffix";
    $self->result->$filename_method($source_file_name);
    my $yield = $stats->yield($read);
    my $method_name = 'yield' . $suffix;
    #####
    # The samtools stats files have valiable number of quality columns,
    # depending on the maximum available quality. For example, for NovaSeq
    # data maximum quality is below 40. We assume zero where data for a
    # particulr quality value are not available.
    #
    $self->result->$method_name((defined $yield && defined $yield->{$base_quality})
                                ? round($yield->{$base_quality}/$THOUSAND) : 0);

    for my $q (@thresholds) {
      my $method_name4q = sprintf '%s_q%i', $method_name, $q;
        $self->result->$method_name4q((defined $yield && defined $yield->{$q})
                                     ? round($yield->{$q}/$THOUSAND) : 0);
    }

    if (!defined $self->tag_index) {
      my $threshold = $self->_get_threshold($reads_length->{$read});
      if (defined $threshold) {
        my $threshold_yield_method = "threshold_yield$suffix";
        $self->result->$threshold_yield_method($threshold);
        push @apass, $self->result->$method_name > $threshold ? 1 : 0;
      } else {
        if ($self->result->$method_name == 0 ) {
          push @apass, 0;
        }
      }
    }
  }

  if (@apass && $self->num_components == 1 &&
    !defined $self->composition->get_component(0)->tag_index) {
    $self->result->pass($self->overall_pass(@apass));
  }

  return 1;
};

sub _get_threshold {
  my ($self, $read_length) = @_;

  if ($self->num_components == 1 && $read_length > 0 && $self->platform_is_hiseq()) {
    my $threshold = $MIN_YIELD_THRESHOLD_KB_HS;
    if ($read_length != $DEFAULT_READ_LENGTH_HS) {
      $threshold = ($read_length * $threshold) / $DEFAULT_READ_LENGTH_HS;
    }
    return round($threshold);
  }

  return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item Readonly

=item Math::Round

=item Try::Tiny

=item npg_qc::autoqc::checks::check

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 GRL

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
