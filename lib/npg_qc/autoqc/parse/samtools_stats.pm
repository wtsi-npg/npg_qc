package npg_qc::autoqc::parse::samtools_stats;

use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use Carp;
use Perl6::Slurp;
use Readonly;
use List::MoreUtils qw/ each_arrayref none uniq /;
use List::Util      qw/ sum /;
use Class::Load     qw/ load_class /;

use npg_tracking::util::types;

our $VERSION = '0';

##no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::autoqc::parse::samtools_stats

=head1 SYNOPSIS

Object instances can be created in a number of ways:

  1. using a samtools stats file path:
     my $f = npg_qc::autoqc::parse::samtools_stats
             ->new(file_path => 'file.stats');
  2. using a path to a serialized to JSON file
     npg_qc::autoqc::results::samtools_stats object:
     my $f = npg_qc::autoqc::parse::samtools_stats
             ->new(file_path => 'samtools_stats.json');
  3. using the content of the samtools stats file:
     my $f = npg_qc::autoqc::parse::samtools_stats
             ->new(file_content => $content_as_string);
     my $f = npg_qc::autoqc::parse::samtools_stats
             ->new(file_content => $content_as_array_of_strings);
  4. using an instance of npg_qc::autoqc::parse::samtools_stats
     object:
     my $f = npg_qc::autoqc::parse::samtools_stats
             ->new(file_content => $samtools_stats_result_object);
  5. using a DBIx object - a row retrieved from the samtools_stats
     database table:
     my $f = npg_qc::autoqc::parse::samtools_stats
             ->new(file_content => $dbix_db_row);

=head1 DESCRIPTION

Parser for samtools stats files. The parser is not comprehensive,
ie it does not try to parse information from all possible sections
of these files.

=cut

Readonly::Scalar my $FORWARD_READ      => 'forward';
Readonly::Scalar my $REVERSE_READ      => 'reverse';
Readonly::Scalar my $INDEX_READS       => 'index';
Readonly::Scalar my $TOTAL             => 'total';
Readonly::Array  my @VALID_READ_NAMES  => ($FORWARD_READ, $REVERSE_READ, $INDEX_READS);

Readonly::Scalar my $SINGLE_VALUE_SECTION   => 'SN';
Readonly::Hash   my %QUALITY_SECTIONS       => ( $FORWARD_READ => 'FFQ',
                                                 $REVERSE_READ => 'LFQ',
                                                 $INDEX_READS  => 'QTQ', );
Readonly::Hash   my %BASE_FRACTION_SECTIONS => ( $FORWARD_READ => 'FBC',
                                                 $REVERSE_READ => 'LBC',
                                                 $INDEX_READS  => 'BCC', );

Readonly::Array  my @BASES       => qw/ A C G T /;
Readonly::Scalar my $MIN_QUALITY => 0;
Readonly::Scalar my $HUNDRED     => 100;

Readonly::Scalar my $RESULT_CLASS_NAME => 'npg_qc::autoqc::results::samtools_stats';

####################################################################
#              Custom types and coercion of types                  #
####################################################################

subtype 'npg_qc::sstats::lines::array',
  as 'ArrayRef[Str]';

coerce 'npg_qc::sstats::lines::array',
  from 'Str',
  via { $_ or croak 'Content string cannot be empty';
        [(split /\n/xms)]};

coerce 'npg_qc::sstats::lines::array',
  from 'Object',
  via { my $class = ref;
        ($class eq $RESULT_CLASS_NAME) or
        ($class eq 'npg_qc::Schema::Result::SamtoolsStats') or
          croak 'Not autoqc samtools stats object';
        [(split /\n/xms, $_->stats)] };

####################################################################
#                  Public attributes and methods                   #
####################################################################

=head1 SUBROUTINES/METHODS

=head2 file_path

A path to an existing samtools stats file. Will be disregarded if the
file_content attribute is set in the constructor. 

=cut

has 'file_path' => (
  isa       => 'NpgTrackingReadableFile',
  is        => 'ro',
  required  => 0,
  predicate => 'has_file_path',
);

=head2 file_content

File content as a list of lines. A lazy attribute, which can be built if
the file_path attribute is set. If the file path has .json extension,
it is assumed that it represents a serialized npg_qc::autoqc::results::samtools_stats
object. Any other file type file is assumed to be in the format of samtools
stats file. 

Coercion is implemented for this attribute. A string value will be converted
to a list of individual lines. Samtools stats autoqc object instance (either
npg_qc::autoqc::checks::samtools_stats or npg_qc::Schema::Result::SamtoolsStats)
will be converted to a list of individual lines of the samtools stats file.

=cut

has 'file_content' => (
  isa        => 'npg_qc::sstats::lines::array',
  is         => 'ro',
  required   => 0,
  coerce     => 1,
  lazy_build => 1,
);
sub _build_file_content {
  my $self = shift;
  my @c;
  if ($self->has_file_path) {
    my $content;
    if ( $self->file_path =~ /\.json\Z/ixms) {
      load_class $RESULT_CLASS_NAME;
      $content = $RESULT_CLASS_NAME->load($self->file_path)->stats;
    } else {
      $content = slurp $self->file_path;
    }
    if (!$content) {
      croak 'No content in ' . $self->file_path;
    }
    @c = split /\n/xms, $content;
  } else {
    croak 'File path not given, cannot build samtools stats file content';
  }
  return \@c;
}

=head2 num_reads

Number of reads hashed by read type. An attribute, cannot be set. 

  print 'Number of forward reads ' . $obj->num_reads->{'forward'};
  print 'Number of forward reads ' . $obj->num_reads->{'reverse'};
  print 'Number of forward reads ' . $obj->num_reads->{'total'};

=cut

has 'num_reads' => (
  isa        => 'HashRef',
  is         => 'ro',
  required   => 0,
  init_arg   => undef,
  lazy_build => 1,
);
sub _build_num_reads {
  my $self = shift;

  my ($n1) = $self->_summary =~ /\s 1stfragments:(\d+)  \s/xms;
  my ($n2) = $self->_summary =~ /\s lastfragments:(\d+) \s/xms;
  my ($n3) = $self->_summary =~ /\s sequences:(\d+)     \s/xms;
  (defined $n1 and defined $n2 and defined $n3) or croak 'Failed to get number of reads';

  return {$FORWARD_READ => $n1, $REVERSE_READ => $n2, $INDEX_READS => $n1, $TOTAL => $n3};
}

=head2 reads_length

Length of reads hashed by read type. An attribute, cannot be set.

  print 'Forward read length '  . $obj->reads_length->{'forward'};
  print 'Reverse reads length ' . $obj->reads_length->{'reverse'};

=cut

has 'reads_length' => (
  isa        => 'HashRef',
  is         => 'ro',
  required   => 0,
  init_arg   => undef,
  lazy_build => 1,
);
sub _build_reads_length {
  my $self = shift;

  my ($n1) = $self->_summary =~ /\s maximumfirstfragmentlength:(\d+) \s/xms;
  my ($n2) = $self->_summary =~ /\s maximumlastfragmentlength:(\d+)  \s/xms;
  ( (defined $n1) and (defined $n2) )
    or croak 'Failed to get reads length';

  return {$FORWARD_READ => $n1, $REVERSE_READ => $n2};
}

=head2 has_reverse_read

Returns a true value if reverse reads are present, false otherwise.

If the number of reads for the reverse read is zero, we assume that
the reverse read does not exist. If the forward reads number is not zero,
conclusion is true. When the forward reads number is zero, this migh
or might not be true.

=cut

sub has_reverse_read {
  my $self = shift;
  return $self->num_reads->{$REVERSE_READ} != 0;
}

=head2 has_no_reads

Returns a true value if the total number of reads is zero, false otherwise.

=cut

sub has_no_reads {
  my $self = shift;
  return $self->num_reads->{$TOTAL} == 0;
}

=head2 yield_per_cycle

Yield, in bases, per cycle for a read (an argument). If no argument is given,
a forward read is assumed. Possible argument values are 'forward',
'reverse', 'index';

Returns a matrix, an array of arrays of integers. Each array element is
an array of yields for a single cycle. The first array element corresponds
to the first cycle, the last to the last cycle. The values in the arrays
of yields correspond to individual qualities starting from 1. The values
are the number of bases at or above a particular quality.

When not data is available for a read, an undefined value is returned.

Example:

  my $m = $obj->yield_per_cycle('reverse');

  789 726 567 467 33 0
  800 700 544 44  32 0
  900 777 530 468  0 0

An array of three arrays representing three cycles. Each element is an
array of six numbers. Maximum quality is six. For cycle two, 544 bases
are at quality three or above. For cycle three, zero bases are of quality
five and above. For cycle one, 789 bases are at quality one and above.

=cut

sub yield_per_cycle {
  my ($self, $read) = @_;

  $read ||= $FORWARD_READ;
  $self->_validate_read_name($read);
  if ( $self->has_no_reads ||
      ($read eq $REVERSE_READ && !$self->has_reverse_read)) {
    return;
  }

  my $matrix = $self->_trim($self->_filter($QUALITY_SECTIONS{$read}));
  #####
  # We need the number of bases  at a particular quality
  # and above for a particular cycle, ie a sum of this number
  # and all numbers in the array the right of this number.
  my $max_quality = scalar @{$matrix->[0]};

  my $transform = sub {
    my $a = shift;
    my $i = $max_quality - 1;
    my $prev = $a->[$i]; # number of bases at max quality
    $i--;
    while ($i >= 0) {
      $a->[$i] = $a->[$i] + $prev;
      $prev = $a->[$i];
      $i--;
    }
    return $a;
  };

  $matrix = [map { $transform->($_) } @{$matrix}];

  return $matrix;
}

=head2 yield

Overall yield in bases for a read (an argument). If no argument is given,
a forward read is assumed. Possible argument values are 'forward',
'reverse', 'index';

An array of integers is returned. The values in the array represent
yields at qualities starting from 1. The values are the number of bases
at or above a particular quality.

When not data is available for a read, an undefined value is returned.

Example:

  my $a = $obj->yield('forward');

  89765 78954 6987 55 0

Maximum quality is five. 78954 bases are at quality 2 or above.

=cut

sub yield {
  my ($self, $read) = @_;

  my $yields = $self->yield_per_cycle($read);
  if (defined $yields) {
    my $ea = each_arrayref @{$yields};
    my @total_yields = ();
    while ( my @yields_per_q = $ea->() ) {
      push @total_yields, sum @yields_per_q;
    }

    my $q = $MIN_QUALITY;
    my %yield_per_quality = map { $q++ => $_ } @total_yields;

    return \%yield_per_quality;
  }
  return;
}

=head2 base_composition

Returns a reference to a hash where the keys are the bases (A, C, G, T) and
the value for each key is the percent of the relevant base. The percent
values are rounded to two digits after the decimal point.

String read argument is optional and defaults to a forward read. Possible
values - 'forward', 'reverse';

  my $bases = $p->base_composition();
  my $read = 'forward';
  $bases = $p->base_composition($read);
  $read = 'forward';
  $bases = $p->base_composition($read);

=cut

sub base_composition {
  my ($self, $read) = @_;

  $read ||= $FORWARD_READ;
  $self->_validate_read_name($read);
  if ( $self->has_no_reads ||
      ($read eq $REVERSE_READ && !$self->has_reverse_read)) {
    return;
  }

  my $matrix = $self->_filter($BASE_FRACTION_SECTIONS{$read});
  my $num_cycles = scalar @{$matrix};

  $matrix = $self->_trim($matrix, $read);
  my $ea = each_arrayref @{$matrix};
  my @means = ();
  my $num_columns = scalar @BASES;

  my $count = 0;
  while ($count < $num_columns) {
    my @column = $ea->();
    if (!@column) {
      croak 'Data missing';
    }
    push @means, sqrt( (sum map { $_ ** 2 } @column) / $num_cycles);
    $count++;
  }

  my $total = sum @means;
  @means = map { sprintf '%.2f', $_ }
               map { ($_ * $HUNDRED) / $total }
               @means;

  (scalar @means == scalar @BASES) or croak 'Mismatching list lengths';
  my $fractions = {};
  foreach my $base (@BASES) {
    $fractions->{$base} = shift @means;
  }

  return $fractions;
}

####################################################################
#                Private attributes and methods                    #
####################################################################

has '_summary' => (
  isa        => 'Str',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
);
sub _build__summary {
  my $self = shift;
  return join q[ ],
         map { join q[], @{$_} }
         @{$self->_filter($SINGLE_VALUE_SECTION)};
}

sub _validate_read_name {
  my ($self, $read) = @_;
  if ( none { $_ eq $read } @VALID_READ_NAMES ) {
    croak "Invalid read name '$read', valid names: " . join q[, ], @VALID_READ_NAMES;
  }
  return;
}

sub _filter {
  my ($self, $filter_name) = @_;

  $filter_name or croak 'Filter name required';

  @{$self->file_content} || croak 'Content is empty - zero lines';

  #####
  # First column is the filter name. We use it to
  # filter out the lines we need, then we remove this
  # column from the matrix.
  #

  my @matrix = grep { $_ =~ /^$filter_name/xms }         # filter
               @{$self->file_content};
  if (!@matrix) {
    croak "$filter_name section is missing";
  }
  ##no critic (BuiltinFunctions::ProhibitComplexMappings)
  @matrix = map { my @a = split /\s+/xms; shift @a; \@a } # remove first column
            @matrix;
  ##use critic
  return \@matrix;
}

sub _trim {
  my ($self, $matrix, $read) = @_;

  my @width = uniq map { scalar @{$_} } @{$matrix};
  if (@width > 1) {
    croak 'Irregular row width';
  }
  #####
  # The first column is cycle numbers. We expect at least two columns.
  if ($width[0] <= 1) {
    croak 'No data in rows';
  }
  #####
  # Drop column with cycle numbers.
  ##no critic (BuiltinFunctions::ProhibitComplexMappings)
  $matrix = [map { shift @{$_}; $_ } @{$matrix}];

  return $matrix;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Moose::Util::TypeConstraints

=item Perl6::Slurp

=item namespace::autoclean

=item Carp

=item List::MoreUtils

=item Readonly

=item List::Util

=item Class::Load

=item npg_tracking::util::types

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) Genome Research Limited 2018

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
