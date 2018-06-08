package npg_qc::autoqc::checks::sequence_error;

use Moose;
use namespace::autoclean;
use Readonly;
use Carp;
use English qw(-no_match_vars);
use File::Basename;
use File::Spec::Functions qw(catfile);

use npg_common::extractor::fastq qw(read_count);
use npg_common::Alignment;
use npg_qc::autoqc::types;
extends qw(npg_qc::autoqc::checks::check);
with qw(
  npg_tracking::data::reference::find
  npg_common::roles::SequenceInfo
  npg_common::roles::software_location
);
has '+aligner' => (default => 'bwa0_6', is => 'ro');

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd ProhibitParensWithBuiltins ProhibitStringySplit RequireNumberSeparators)

Readonly::Scalar our $DEFAULT_NUM_READS   => 10000;
Readonly::Scalar our $CIGAR_INDEX         => 5;
Readonly::Scalar our $SEQUENCE_INDEX      => 9;
Readonly::Scalar our $QUALITY_INDEX       => 10;
Readonly::Scalar our $ORIENTATION_SHIFT   => 4;
Readonly::Scalar our $ORIENTATION_REVERSE => 16;
Readonly::Scalar our $UNMAPPED            => 0x4;
Readonly::Array  our @PREFIX_METHOD       => qw(forward reverse);
Readonly::Scalar our $LOW_RANGE           => 15;
Readonly::Scalar our $MID_RANGE           => 30;
Readonly::Scalar our $HIGH_RANGE          => 31;

use PDL::Lite; use PDL::Core qw(pdl); use PDL::Basic qw(yvals);
Readonly::Scalar our $CIGAR_VALID_CHAR => q(MDINPHS);
Readonly::Scalar our $NUM_TOP_CIGARS => 5;

=head2 reference

A path to reference

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
    1;
  } or do {
    my $error_message = qq{Error: binary reference cannot be retrieved; cannot run sequence_error check. $EVAL_ERROR};
    $self->result->add_comment($error_message);
    return;
  };

  if ($self->messages->count) {
    $self->result->add_comment(join q[ ], $self->messages->messages);
  }

  if (scalar @refs > 1) {
    $self->result->add_comment(q[multiple references found: ] . (join q[;], @refs));
    return;
  }

  if (scalar @refs == 0) {
    $self->result->add_comment(q[Failed to retrieve binary reference.]);
    return;
  }

  return (pop @refs);
}

=head2 sample_size

Number of reads to use, defaults to 10,000

=cut

has 'sample_size'   => (isa             => 'SampleSize4Aligning',
                        is              => 'ro',
                        required        => 0,
                        default         => $DEFAULT_NUM_READS,
                       );

=head2 _actual_sample_size

Actual number of reads used

=cut

has '_actual_sample_size'   => (isa             => 'Maybe[SampleSize4Aligning]',
                                is              => 'ro',
                                required        => 0,
                                writer          => '_set_actual_sample_size',
                               );

=head2 aligner_options

bwa command options
 
=cut

has 'aligner_options' => (isa             => 'Str',
                          is              => 'rw',
                          required        => 0,
                          default         => q{-n 60},
                         );

override 'execute'    => sub {

  my $self = shift;

  super();

  if(!$self->reference()){
    return 1;
  }
  $self->bwa0_6_cmd;
  $self->process_all_fastqs();

  if (defined $self->_actual_sample_size) {
    $self->result->reference($self->reference);
    $self->result->set_info( 'Aligner', $self->bwa0_6_cmd );
    $self->result->set_info( 'Aligner_version',  $self->current_version($self->bwa0_6_cmd) );

    if($self->aligner_options()){
      $self->result->set_info( 'Aligner_options', $self->aligner_options() );
    }

    $self->_calc_and_set_pass();

  }

  return 1;
};

sub _calc_and_set_pass {
  my $self = shift;
  #set pass if commonest cigar strings for forward and reverse are without I or D
  if(my $fcc = $self->result->forward_common_cigars){
    if($fcc->[0] && (my $cig=$fcc->[0][0])){
      my $rcc = $self->result->reverse_common_cigars;
      if($rcc->[0] && (my $rcig=$rcc->[0][0])){ $cig .= $rcig; }
      $self->result->pass( $cig =~ /[ID]/smgx ? 0 : 1 );
    }
  }
  return;
}

sub process_all_fastqs{
  my $self = shift;

  my @fastqs = @{$self->input_files};
  if( scalar @fastqs > 2 ){
    croak "too many fastqs found: @fastqs";
  }

  my $count = 0;

  foreach my $fastq (@fastqs){
    carp "Checking error rate: $fastq\n";
    $self->process_one_fastq($fastq, $PREFIX_METHOD[$count]);
    $count++;
  }
  if (defined $self->_actual_sample_size) {
    $self->result->sample_size($self->_actual_sample_size);
  }
  return 1;
}

sub process_one_fastq{
  my ($self, $fastq, $fastq_direction) = @_;

  #prepare temp file names
  my $out_dir = $self->tmp_path;
  my ($filename, $directories, $suffix) = fileparse($fastq, qr{.fastq}mxs);
  my $sam_out = catfile($out_dir, $filename.q{.sam});

  my $actual_sample_size = read_count($fastq);
  eval {
    $self->_set_actual_sample_size($actual_sample_size);
    1;
  } or do {
    $self->result->add_comment(qq[Too few reads in $fastq? Number of reads $actual_sample_size] . q[.]);
    return 1;
  };
  #use input fastq, doing alignment
  my $alignment = npg_common::Alignment->new(
                               bwa_cmd => $self->bwa0_6_cmd, #propagate bwa command
                               bwa_options => $self->aligner_options(),
                             );
  eval{

    $alignment->bwa_align_se({
      fastq => $fastq,
      bam_out => $sam_out,
      ref_root => $self->reference(),
    });
    1;
  } or do{
    croak q[Error in doing alignment: ].$EVAL_ERROR;
  };

  my $results_hash = {};
  eval{
    $results_hash = $self->parsing_sam($sam_out, $fastq_direction);
    1;
  } or do{
    croak q[Error when parsing sam file: ].$EVAL_ERROR;
  };

  my $error_by_base         = $results_hash->{error_by_base};
  my $count_total           = $results_hash->{count_total};
  my $num_reads_aligned     = $results_hash->{num_reads_aligned};
  my $num_reads_not_aligned = $results_hash->{num_reads_not_aligned};
  my $n_count_by_base       = $results_hash->{n_count_by_base};
  my $quality_struct        = $results_hash->{quality_struct};

  #store the result
  if( ( $num_reads_aligned + $num_reads_not_aligned ) != $self->_actual_sample_size ){
       croak 'Total reads in the sam file is not equal to the sample size';
  }

  my $method_name = $fastq_direction.q{_errors};
  $self->result()->$method_name($error_by_base);

  $method_name = $fastq_direction.q{_n_count};
  $self->result()->$method_name($n_count_by_base);

  $method_name = $fastq_direction.q{_count};
  $self->result()->$method_name($count_total);

  $method_name = $fastq_direction.q{_aligned_read_count};
  $self->result()->$method_name($num_reads_aligned);

  $method_name = $fastq_direction.q{_read_filename};
  $self->result()->$method_name("$filename$suffix");

  my $insert_array = [];
  my $bin_names = [];
  foreach my $bin_name ( reverse sort { $a <=> $b } keys %{ $quality_struct } ) {
    push @{ $bin_names }, $bin_name;
    push @{ $insert_array }, $quality_struct->{ $bin_name };
  }

  $method_name = $fastq_direction.q{_quality_bins};
  $self->result()->$method_name($insert_array);

  $self->result()->quality_bin_values($bin_names);

  $method_name = $fastq_direction.q{_common_cigars};
  $self->result()->$method_name($results_hash->{common_cigars});

  $method_name = $fastq_direction.q{_cigar_char_count_by_cycle};
  $self->result()->$method_name($results_hash->{cigar_char_count_by_cycle});

  return 1;
}

sub parsing_sam{
  my ($self, $sam) = @_;

  my $num_reads_aligned = 0;
  my $num_reads_not_aligned = 0;
  my $error_by_base = [];
  my $read_length;

  my $count_total = [];

  my $n_count_by_base = [];

  my $quality_structure = {
    $LOW_RANGE  => [],
    $MID_RANGE  => [],
    $HIGH_RANGE => [],
  };

  my %cigar_freq;
  my $cig_vs_cycle_count_pdl;

  my $qname = {};
  open my $sam_fh, '<', $sam ## no critic (InputOutput::RequireBriefOpen)
  or croak "can not open file $sam: $ERRNO";

  while ( my $line = <$sam_fh> ){

    chomp $line;

    if($line =~ /^@/mxs){
      next;
    }

    my ($md) = $line =~ /MD\:Z\:(\S*)/mxs;
    my @fields = split /\t/mxs, $line;
    my $cigar = $fields[$CIGAR_INDEX];


    my $flag = $fields[1];

    if($qname->{$fields[0]}){
      next;
    }else{
      $qname->{$fields[0]} = 1;
    }

    if( not ($flag & $UNMAPPED) ){

      my ($match_array, $count) = $self->matches_per_base($md, $cigar, $flag);
      $self->_collate_uncalled( {
        match_array => $match_array,
        sequence => $fields[$SEQUENCE_INDEX],
        count_array => $n_count_by_base,
        flag => $flag,
      } );

      $self->_collate_qualities( {
        match_array => $match_array,
        quality_struct => $quality_structure,
        sequence => $fields[$SEQUENCE_INDEX],
        quality_string => $fields[$QUALITY_INDEX],
        flag => $flag,
      } );
      my $current_read_length = scalar @{$match_array};
      $self->_add_array($error_by_base, $match_array);
      $self->_add_array($count_total, $count);

      if( $num_reads_aligned == 0 ){
        $read_length = $current_read_length;
      }

      if( $read_length != $current_read_length ){
        croak "different read length in the alignment: $sam\n:$md ".$cigar ;
      }

      $num_reads_aligned++;

      my $forward_cigar = $self->check_read_orientation($flag) ? _reverse_cigar($cigar) : $cigar ;
      $cigar_freq{ $forward_cigar }++;
      my $cig_vs_cycle_pdl = _cigar_to_cycle_vs_cigar_pdl($forward_cigar);
      if(defined $cig_vs_cycle_count_pdl){
        $cig_vs_cycle_count_pdl += $cig_vs_cycle_pdl;
      }else{
        $cig_vs_cycle_count_pdl = $cig_vs_cycle_pdl;
      }

    }else{
      $num_reads_not_aligned++;
    }
  }

  close $sam_fh or croak "cannot close file $sam: $ERRNO";

  foreach my $base_count ( @{ $n_count_by_base } ) {
    $base_count ||= 0;
  }

  my @cigar_freq;
  while (my@cigar_and_count_pair=each %cigar_freq){push @cigar_freq, \@cigar_and_count_pair;}
  @cigar_freq = (reverse sort {$a->[1] <=> $b->[1]} @cigar_freq)[0..($NUM_TOP_CIGARS-1)]; #pick top cigars

  return {
    error_by_base => $error_by_base,
    count_total   => $count_total,
    num_reads_aligned => $num_reads_aligned,
    num_reads_not_aligned => $num_reads_not_aligned,
    n_count_by_base => $n_count_by_base,
    quality_struct => $quality_structure,
    common_cigars => \@cigar_freq,
    cigar_char_count_by_cycle => { map {
      _extract_per_cycle_count_listref_for_cigar_char($cig_vs_cycle_count_pdl, $_)
    } split q(),$CIGAR_VALID_CHAR},
  };
}

sub _reverse_cigar {
  my $cigar = shift;
  my @revcig;
  while($cigar =~ /(\d*[$CIGAR_VALID_CHAR])/gmxsi){ unshift @revcig, $1; }
  return join q(),@revcig;
}

sub _cigar_to_cycle_vs_cigar_pdl {
  my $forward_cigar = shift;
  #Now convert this cigar string to one character per cycle
  my $char_only_cigar = join q(), map{ _expand_digit_char_to_repeat_chars($_) } $forward_cigar =~ /\d*[$CIGAR_VALID_CHAR]/gmxsi;
  $char_only_cigar =~ s/D+[^D]/D/smgix; # squash Ds and replace following
  #then convert CIGAR chars to integers
  #then bung in a pdl
  my $cig_index_by_cycle_pdl = pdl map{ index $CIGAR_VALID_CHAR,$_ } split q(), $char_only_cigar;
  # convert to 2d pdl filled with 1s and 0s - one dimension cycle, other dimension for each valid CIGAR char
  return yvals(1,length($CIGAR_VALID_CHAR))==$cig_index_by_cycle_pdl;
}

sub _expand_digit_char_to_repeat_chars{
  local $_ = shift;
  if (/(\d*)([$CIGAR_VALID_CHAR])/mxsi){
    return ($2) x $1;
  }
  return;
}

sub _extract_per_cycle_count_listref_for_cigar_char {
  my ($cig_vs_cycle_count_pdl, $cigar_char) = @_;
  if (defined $cig_vs_cycle_count_pdl) {
    my $slice = $cig_vs_cycle_count_pdl->slice(q(,).index $CIGAR_VALID_CHAR, $cigar_char)->flat;
    return $cigar_char => ( $slice->max ? [$slice->list] : undef ) ;
  }
  return $cigar_char => undef;
}

sub _add_array{
  my ( $self, $array1, $array2 ) = @_;

  foreach my $index ( 0 .. scalar @{$array2} - 1 ){

    $array1->[$index] += $array2->[$index];
  }
  return $array1;
}

sub parsing_md_string{
  my ($self, $md) = @_;

  my @match_array;
  my $base_index = 0;

  my ( $first_num_matches ) = $md =~ /^(\d+)/mxs;


  foreach my $base (1 .. $first_num_matches){

    $match_array[$base_index] = 0;
    $base_index++;
  }

  my $substring = substr $md, length $first_num_matches;

  return \@match_array if(!$substring);

  while ($substring =~ /(([ACGTN]|\^[ACGTN]+)(\d+))/gmxsi){

    my $non_match = $2;
    my $match = $3;

    if( $non_match !~ /^\^/mxs ){

       foreach my $base ( 1 .. length $non_match ){

         $match_array[$base_index] = 1;
         $base_index++;
       }
    }

    foreach my $base ( 1 .. $match ){

      $match_array[$base_index] = 0;
      $base_index++;
    }
  }
  return \@match_array;
}

sub parsing_md_string_eland{
  my ($self, $md) = @_;

  my @match_array;
  my $base_index = 0;
  foreach my $field (split /([:ACGTNX])/xmsi, $md) {

    if ($field =~ /^[ACGTNX]$/xmsi) {
      $match_array[$base_index] = 1;
      $base_index++;
    } elsif ($field ne q{} and $field ne q{:}) {

      foreach my $index (1 .. $field ){

        $match_array[$base_index] = 0;
        $base_index ++;
      }
    }

  }

  return \@match_array;
}

sub matches_per_base_eland{
  my ($self, $md, $cigar, $flag) = @_;

  my $match_array_by_md = $self->parsing_md_string_eland($md);
  #no need reverse
  #and also no need to use cigar string because no deletion here

  return $match_array_by_md;
}

sub modify_match_by_cigar{
  my ($self, $cigar, $match_array, $md) = @_;
  my $count = [];

  if ( $cigar !~ /[IHS]/mxs ){
    $count = [ map {1} @{$match_array} ];
    return ($match_array, $count);
  }

  my @new_match_array;
  my $base_index1 = 0;
  my $base_index2 = 0;

  while($cigar =~ /(\d+)([$CIGAR_VALID_CHAR])/gmxsi){

    my $number = $1;
    my $operation = $2;

    if( $operation eq q{M} ){

      foreach my $base (1 .. $number){
        $new_match_array[$base_index1] = $match_array->[$base_index2];
        $count->[$base_index1] = 1;
        $base_index1++;
        $base_index2++;
      }
    }elsif( $operation =~ /[I]/mxsi  ){

      foreach my $base (1 .. $number){
        $new_match_array[$base_index1] = 0;
        $count->[$base_index1] = 0;
        $base_index1++;
      }
    }
    elsif( $operation =~ /[SH]/mxsi  ){

      foreach my $base (1 .. $number){
        $new_match_array[$base_index1] = 1;
        $count->[$base_index1] = 1;
        $base_index1++;
      }
    }

  }
  return (\@new_match_array, $count);
}

sub check_read_orientation{
  my ($self, $flag) = @_;

  return ($flag & $ORIENTATION_REVERSE ) >> $ORIENTATION_SHIFT;
}

sub matches_per_base{
  my ($self, $md, $cigar, $flag) = @_;

  my $match_array_by_md = $self->parsing_md_string($md);

  my ($error_by_base, $count) =  $self->modify_match_by_cigar( $cigar, $match_array_by_md, $md );

  my $reverse = $self->check_read_orientation( $flag );

  if(!$reverse){
     return ($error_by_base, $count);
  }
  my @error_by_base_reverse =  reverse @{$error_by_base};
  my @count_reverse = reverse @{$count};
  return (\@error_by_base_reverse, \@count_reverse );
}

sub _collate_uncalled{
  my ( $self, $arg_refs ) = @_;

  my $seq = uc $arg_refs->{sequence};
  my $count_array = $arg_refs->{count_array};

  if ( $self->check_read_orientation( $arg_refs->{flag} ) ) {
    $seq = reverse $seq;
  }

  if ( scalar @{ $count_array } == 0 ) {
    $count_array->[ ( length $seq ) - 1 ] = 0;
  }
  foreach my $index ( $self->indices_of_base( $seq, q{N} ) ) {
    if ( $arg_refs->{match_array}->[$index] ) {
      $count_array->[$index]++;
    }
  }
  return 1;
}

sub _collate_qualities {
  my ( $self, $arg_refs ) = @_;

  my $quality_string  = $arg_refs->{quality_string};
  my $sequence        = $arg_refs->{sequence};

  if ( $self->check_read_orientation( $arg_refs->{flag} ) ) {
    $quality_string = reverse $quality_string;
    $sequence       = reverse $sequence;
  }

  my $quality_struct = $arg_refs->{quality_struct};

  foreach my $key ( keys %{ $quality_struct } ) {
    if ( ! scalar @{ $quality_struct->{ $key } } ) {
      foreach my $match ( @{ $arg_refs->{match_array} } ) {
        push @{ $quality_struct->{ $key } }, 0;
      }
    }
  }

  my $index = 0;
  foreach my $match ( @{ $arg_refs->{match_array} } ) {
    my $this_index = $index;
    $index++;
    next if ! $match;
    next if uc(substr $sequence, $this_index, 1) eq q{N};

    my $base_quality = substr $quality_string, $this_index, 1;
    $base_quality = $self->convert_to_quality_score( $base_quality );

    my $array = $base_quality < ($LOW_RANGE + 1) ? $LOW_RANGE
              : $base_quality < ($MID_RANGE + 1) ? $MID_RANGE
              :                                    $HIGH_RANGE
              ;
    $quality_struct->{$array}->[$this_index]++;
  }

  return 1,
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

npg_qc::autoqc::checks::sequence_error

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Carp

=item English -no_match_vars

=item Readonly

=item npg_qc::autoqc::checks::check

=item npg_qc::autoqc::align::reference

=item npg_common::Alignment

=item npg_common::extractor::fastq qw(read_count)

=item npg_common::roles::software_location

=item File::Basename

=item File::Spec::Functions qw(catfile)

=item PDL

=item npg_tracking::data::reference::find

=back

=head1 SUBROUTINES/METHODS

=head2 check_read_orientation

  parsing flag field in sam file, return the orientation of the alignment

=head2 matches_per_base

  given md, cigar string, and flag for each read, return an array of 0 and 1 values.
  0 for not- mismatch and 1 for mismatch.
  Parsing md string first and add positions of insertion, soft and hard clipping,
  as not mismatch. And then reverse it if necessary based on flag

=head2 matches_per_base_eland

  the export output of eland no gap and no need reverse the md string, md string
  enough to check mismatch

=head2 modify_match_by_cigar

  there is no insertion clipping information in md string, modify the mismatch
  array by checking cigar string 

=head2 parsing_md_string

  given a md string, return an array of 0 and 1, 0 for not- mismatch and 1 for mismatch.
  Ignore the deletion in the read

=head2 parsing_md_string_eland

  md string in eland not follow the latest sam specification

=head2 parsing_sam

  given a sam file, return an array,
  representing the total number of mismatch for each cycle

=head2 process_all_fastqs

  process all fastq files

=head2 process_one_fastq

  process one fastq

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
