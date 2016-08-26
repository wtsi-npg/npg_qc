package npg_qc::autoqc::checks::insert_size;

use Moose;
use namespace::autoclean;
use Moose::Meta::Class;
use Moose::Util::TypeConstraints;
use Carp;
use English qw(-no_match_vars);
use Readonly;
use File::Spec::Functions qw(catfile);
use Math::Round qw(round);
use List::Util;
use Perl6::Slurp;

#########################################################
# 'extends' should prepend 'with' since the
# fields required by the npg_qc::autoqc::align::reference
# role are defined there; there is a bug in Moose::Role
#########################################################
extends qw(npg_qc::autoqc::checks::check);
with qw(
  npg_tracking::data::reference::find
  npg_common::roles::software_location
       );

use npg::api::run;
use npg_qc::autoqc::types;
use npg_qc::autoqc::parse::alignment;
use npg_qc::autoqc::results::insert_size;
use npg_common::Alignment;
use npg_common::extractor::fastq qw(generate_equally_spaced_reads);

our $VERSION = '0';

Readonly::Scalar my $NORM_FIT_EXE                           => q[norm_fit];
Readonly::Scalar my $NORM_FIT_MIN_PROPERLY_ALIGNED_PAIRS    => 5000;
Readonly::Scalar my $NORM_FIT_MAX_BIN_THRESHOLD             => 0.9;
Readonly::Scalar my $NORM_FIT_CONFIDENCE_PASS_LEVEL  => 0.0;

## no critic (Documentation::RequirePodAtEnd RequireCheckingReturnValueOfEval ProhibitParensWithBuiltins RequireNumberSeparators)
=head1 NAME

npg_qc::autoqc::checks::insert_size

=head1 SYNOPSIS

Inherits from npg_qc::autoqc::checks::check. See description of attributes in the documentation for that module.
  my $check = npg_qc::autoqc::checks::insert_size->new(
          path => q[/staging/IL29/analysis/090721_IL29_3379/data], position => 1
                                                      );

=head1 DESCRIPTION

An insert size check performs paired alignment in order to determine the actual insert size, which is then compared to the insert size requested by the user.

=head1 SUBROUTINES/METHODS

=cut


Readonly::Scalar our $NUM_READS              => 10000;
Readonly::Scalar our $THOUSAND               => 1000;
Readonly::Scalar our $RANGE_EXPANSION_COEFF  => 0.25;
Readonly::Scalar our $MAX_ISIZE_COEFF        => 2;
Readonly::Scalar our $CHILD_ERROR_SHIFT      => 8;

our $_alignment_count = 0; ## no critic (Variables::ProhibitPackageVars)

=head2 sample_size

Number of reads aligned

=cut
has 'sample_size' => (isa         => 'Maybe[SampleSize4Aligning]',
                      is          => 'ro',
                      required    => 0,
                      default     => $NUM_READS,
                     );

=head2 actual_sample_size

Actual number of reads used

=cut

has 'actual_sample_size'   => (isa             => 'Maybe[SampleSize4Aligning]',
                               is              => 'ro',
                               required        => 0,
                               writer          => '_set_actual_sample_size',
                              );

=head2 aligner_options

bwa command options
 
=cut

has 'aligner_options' => (isa             => 'Str',
                          is              => 'ro',
                          required        => 0,
                          default         => q{},
                         );

=head2 use_reverse_complemented

a boolen flag to indicate whether reverse complemented fastq files should be produced,
aligned and analysed, defaults to 1
 
=cut

has 'use_reverse_complemented' => (isa             => 'Bool',
                                   is              => 'ro',
                                   required        => 0,
                                   default         => 1,
                                  );

=head2 expected_size

Expected size range as a reference to an array that contains pairs of I<from> and I<to> values. Undefined if the field has not been set by the user and the sutobuild procedure has failed. In the simplest case the $is->extected_size->[0] contains a I<from> value and $is->extected_size->[1] contains a I<to> value. In case of a multiplexed lane, further values might be present in the array.

=cut
has 'expected_size'   => (isa         => 'Maybe[ArrayRef]',
                          is          => 'ro',
                          required    => 0,
                          lazy_build  => 1,
                         );

sub _build_expected_size {
    my $self = shift;

    my $sizes_hash;
    eval {
	$sizes_hash = $self->lims->required_insert_size;
        1;
    } or do {
        $self->result->add_comment($EVAL_ERROR);
        return;
    };
    if (keys %{$sizes_hash} == 0) {
        $self->result->add_comment('Expected insert size is not defined');
        return;
    }
    return $self->_read_insert_size_hash($sizes_hash);
}


=head2 reference

A path to reference against which the two fastq files are aligned.

=cut
has 'reference'   => (isa         => 'Maybe[Str]',
                      is          => 'ro',
                      required    => 0,
                      lazy_build  => 1,
                     );

sub _build_reference {
    my $self = shift;
    my @refs;
    eval {
        @refs = @{$self->refs()};
    };
    if ($EVAL_ERROR) {
        $self->result->add_comment(q[Error: binary reference cannot be retrieved; cannot run insert size check. ] . $EVAL_ERROR);
        return;
    }

    if ($self->messages->count) {
        $self->result->add_comment(join(q[ ], $self->messages->messages));
    }

    if (scalar @refs > 1) {
	$self->result->add_comment(q[multiple references found: ] . join(q[;], @refs));
        return;
    }

    if (scalar @refs == 0) {
        $self->result->add_comment(q[Failed to retrieve binary reference.]);
        return;
    }
    return (pop @refs);
}

=head2 format

format for paired alignment
 
=cut

has 'format'          => (isa             => 'Str',
                          is              => 'ro',
                          required        => 0,
                          default         => q[sam],
                         );

=head2 format

format for paired alignment
 
=cut

has 'norm_fit_cmd' => (
        is      => 'ro',
        isa     => 'NpgCommonResolvedPathExecutable',
        coerce  => 1,
        default => $NORM_FIT_EXE,
);

override 'can_run'            => sub {
  my $self = shift;
  return npg::api::run->new({id_run => $self->id_run})->is_paired_read();
};

override 'execute'            => sub {
  my $self = shift;
  if(!super()) {return 1;}

  if (!$self->can_run) {
      $self->result->add_comment(q[Single run. Cannot run insert size check.]);
      return 1;
  }

  my @files = @{$self->input_files};
  $self->result->filenames($self->generate_filename_attr());
  if (@files == 1) {croak q[Reverse run fastq file is missing];}

  if (!$self->reference) { return 1; }

  $self->result->set_info( 'Aligner', $self->bwa_cmd() );
  $self->result->set_info( 'Aligner_version',  $self->current_version( $self->bwa_cmd() ) );
  if($self->aligner_options()){
    $self->result->set_info( 'Aligner_options', $self->aligner_options() );
  }
  $self->_set_additional_modules_info();

  my $sample_reads = $self->_generate_sample_reads();
  if (!$sample_reads) {
      $self->result->pass(0);
      return 1;
  }

  $self->result->reference($self->reference);

  my @input = ($self->_align($sample_reads));
  if ($self->use_reverse_complemented) {
      push @input, $self->_align($self->_fastq_reverse_complement($sample_reads));
  }

  eval {
      npg_qc::autoqc::parse::alignment->new(
          files2parse  => \@input,
      )->generate_insert_sizes($self->result);
      1;
  } or do {
      $self->result->add_comment($EVAL_ERROR);
      $self->result->pass(0);
      return 1;
  };

  if (!$self->result->num_well_aligned_reads) {
      $self->result->add_comment(q[No results returned from aligning]);
      $self->result->pass(0);
      return 1;
  }

  if ($self->expected_size && @{$self->expected_size}) {
      $self->result->expected_size($self->expected_size);
      # From a meeting with Mike Quail on 04.09.2009
      my $pass = ($self->expected_size->[0] < $self->result->quartile3) || 0;
      $self->result->pass($pass);
  }

  if ($self->result->num_well_aligned_reads < $NORM_FIT_MIN_PROPERLY_ALIGNED_PAIRS) {
      $self->result->add_comment('Not enough properly paired reads for normal fitting');
      return 1;
  }

  my $max_bin = List::Util::max @{$self->result->bins};
  if ($max_bin > $NORM_FIT_MAX_BIN_THRESHOLD * $self->result->num_well_aligned_reads) {
      $self->result->add_comment('Not enough variation for normal fitting');
      return 1;
  }

  my $input = catfile($self->tmp_path, q[norm_fit.input]);
  my $output = catfile($self->tmp_path, q[norm_fit.output]);

  ## no critic (ProhibitTwoArgOpen Variables::ProhibitPunctuationVars)
  open my $fh, ">$input" or croak qq[Cannot open file $input. $?];
  ## use critic
  $fh->print( $self->result->min_isize . qq[\n]);
  $fh->print( $self->result->bin_width . qq[\n]);
  $fh->print( scalar(@{$self->result->bins}) . qq[\n]);
  $fh->print( (join qq[\n], @{$self->result->bins}) . qq[\n]);
  close $fh or croak qq[Cannot close file $input. $ERRNO];

  my $command = $self->norm_fit_cmd;
  $command .= qq[ $input $output];

  if (system($command) ){
      my $error =  printf "Child %s exited with value %d\n", $command, $CHILD_ERROR >> $CHILD_ERROR_SHIFT;
      croak $error;
  }

  if (! -e $output) {
      $self->result->add_comment('No output from normal fitting');
      return 1;
  }

  my @lines = slurp $output;

  my $norm_fit_pass;
  my @modes = ();
  foreach my $line (@lines) {
      if ($line =~ /^\#/xms) {
          # ignore comments
      } elsif (my ($name,$value) = ($line =~ /^(\S+)=(\S+)$/xms)) {
          # lines containing name=value pairs
          if ($name eq q[nmode]) {
              $self->result->norm_fit_nmode($value);
          } elsif ($name eq q[confidence]) {
              $self->result->norm_fit_confidence($value);
          } elsif ($name eq q[pass]) {
              $norm_fit_pass = $value;
          }
      } else {
          # all other lines are assumed to contain amplitude, mean and optionally std for each mode
          chomp($line);
          my @mode = split q[ ], $line;
          push @modes, \@mode;
      }
  }
  $self->result->norm_fit_modes(\@modes);
  if($self->result->norm_fit_confidence > $NORM_FIT_CONFIDENCE_PASS_LEVEL) {
    $self->result->norm_fit_pass($norm_fit_pass);
  }

  return 1;
};

sub _trim {
    my ($self, $string) = @_;
    $string =~ s/^\s+//smx;
    $string =~ s/\s+$//smx;
    return $string;
}

sub _enforce_number {
    my ($self, $num_string) = @_;

    $num_string = $self->_trim($num_string);
    my $number = int $num_string;
    if ($number ne $num_string && $num_string =~ /k/smxi) {
        my($int_part, $float_part) = $num_string =~/(\d+)?([.]\d+)?/mxs;
        if (!defined $int_part) {$int_part = 0;}
        $number = $int_part;
        if (defined $float_part) { $number += $float_part; }
        $number = $number  * $THOUSAND;
        $number = int $number;
    }

    return $number;
}

sub _read_insert_size_hash {
    my ($self, $sizes_hash) = @_;

    my @sizes = ();
    foreach my $key (keys %{$sizes_hash}) {
        foreach my $boundary (qw/ from to /) {
            if (exists $sizes_hash->{$key}->{$boundary}) {
	        my $value = $sizes_hash->{$key}->{$boundary};
                if (defined $value) {
                    $value = $self->_enforce_number($value);
                    if ($value > 0) {
                        push @sizes, $value;
		    }
	        }
            }
        }
    }

    if (!@sizes) {
        my $message = q[Could not determine expected size for run ] . $self->id_run . q[ lane ] .$self->position;
        if (defined $self->tag_index) {
            $message .= q[ tag index ] . defined $self->tag_index;
	}
        $self->result->add_comment($message);
        return \@sizes;
    }

    my $from = List::Util::min @sizes;
    my $to   = List::Util::max @sizes;
    if ($to == $from) {
        ($from, $to) = $self->_expected_single_value2expected_range($to);
    }
    return [$from, $to];
}


sub _expected_single_value2expected_range {
    my ($self, $value) = @_;
    my $delta = round($value * $RANGE_EXPANSION_COEFF);
    return $value - $delta, $value + $delta;
}

sub _generate_sample_reads {
    my ($self) = @_;

    my $fqe1 =  catfile($self->tmp_path, q[1.fastq]);
    my $fqe2 =  catfile($self->tmp_path, q[2.fastq]);

    my $actual_sample_size;
    eval {
        $actual_sample_size = generate_equally_spaced_reads($self->input_files, [$fqe1, $fqe2], $self->sample_size);
        1;
    } or do {
        my $error = $EVAL_ERROR;
        if ($error =~ /reads[ ]are[ ]out[ ]of[ ]order/ismx) { croak $error; }
        $self->result->add_comment($error);
        return;
    };

    eval {
        $self->_set_actual_sample_size($actual_sample_size);
        1;
    } or do {
        $self->result->add_comment(q[Too few reads in ] . $self->input_files->[0] .q[? Number of reads ] . $actual_sample_size . q[.]);
        return;
    };
    $self->result->sample_size($self->actual_sample_size);

    return [$fqe1, $fqe2];
}

sub _fastq_reverse_complement {
    my ($self, $sample_reads) = @_;

    my @reversed = ();
    foreach my $i (0 .. 1) {
        push @reversed, catfile($self->tmp_path, ($i+1) . q[r.fastq]);
        my @args = (q[fastx_reverse_complement], q[-Q 33], q[-i], $sample_reads->[$i], q[-o], $reversed[$i]);
        print 'Producing reverse complemented file: ' . (join q[ ], @args) . qq[\n] || carp 'Producing reverse complemented file: ' . (join q[ ], @args) . qq[\n];
        if (system(@args)) {
            my $error =  printf "Child %s exited with value %d\n", join(q[ ], @args), $CHILD_ERROR >> $CHILD_ERROR_SHIFT;
            croak $error;
        }
    }
    return \@reversed;
}

sub _set_additional_modules_info {
    my ($self) = @_;

    my @packages_info = qw /npg_qc::autoqc::parse::alignment
                            npg_common::extractor::fastq
                            npg_common::Alignment
                           /;
    ## no critic (TestingAndDebugging::ProhibitNoStrict ValuesAndExpressions::ProhibitInterpolationOfLiterals)
    no strict 'refs';
    @packages_info = map { join q[ ], $_, ${$_."::VERSION"}} @packages_info;
    use strict;
    ## use critic
    if ($self->use_reverse_complemented) {
        push @packages_info, q[FASTX Toolkit fastx_reverse_complement ] . $self->_fastx_version;
    }
    push @packages_info, join q[ ], $self->norm_fit_cmd, $VERSION;
    $self->result->set_info('Additional_Modules', ( join q[;], @packages_info ) );
    return;
}

sub _fastx_version {
    my $self = shift;
    my @lines = slurp 'fastx_reverse_complement -h |';
    foreach my $line (@lines) {
        if ($line =~ /FASTX\ Toolkit/xms) {
            my ($version) = $line =~ /\ (\d+\.\d+\.\d+)\ /xms;
            if ($version) { return $version; }
	}
    }
    return q[];
}

sub _align {
    my ($self, $sample_reads, $prefix) = @_;

    $_alignment_count++;
    my $output_sam = catfile($self->tmp_path, $_alignment_count . q[isize.sam]);
    my $al = npg_common::Alignment->new($self->resolved_paths());
    $al->bwa_align_pe({ref_root => $self->reference, fastq1 => $sample_reads->[0], fastq2 => $sample_reads->[1], sam_out => $output_sam, fork_align => 0,});
    return $output_sam;
}

__PACKAGE__->meta->make_immutable();

1;
__END__


=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Carp

=item English

=item Readonly

=item Moose

=item namespace::autoclean

=item Moose::Meta::Class

=item Math::Round

=item File::Spec::Functions

=item List::Util

=item npg::api::run

=item npg_tracking::data::reference::find

=item npg_common::extractor::fastq

=item npg_common::Alignment

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL, by Marina Gourtovaia

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
