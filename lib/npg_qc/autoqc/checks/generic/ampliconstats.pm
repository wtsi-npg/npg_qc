package npg_qc::autoqc::checks::generic::ampliconstats;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Readonly;
use Carp;
use Perl6::Slurp;
use List::MoreUtils qw/ first_value /;

use st::api::lims;
use npg_qc::autoqc::results::samtools_stats;

extends qw(npg_qc::autoqc::checks::generic);

## no critic (Documentation::RequirePodAtEnd)

our $VERSION = '0';

=head1 NAME

npg_qc::autoqc::checks::generic::ampliconstats

=head1 SYNOPSIS

Examples of invocation via a qc script:
  
  qc --check generic --spec ampliconstats --rpt_list 34761:1:1 \
     --input_files astats.txt --qc_out dir1 --ampstats_section FREADS \
     --pp_name covid --pp_version 33

  qc --check generic --spec ampliconstats --rpt_list 34761:1:1 \
     --input_files astats.txt --qc_out dir1 --ampstats_section FREADS \
     --sample_qc_out dir2

  # When sample_qc_out is a glob, quote the attribute's value to
  # prevent an early glob expansion. The glob expression should
  # contain the '/plex*/' part.
  qc --check generic --spec ampliconstats --rpt_list 34761:1:1 \
     --input_files astats.txt --qc_out dir1 --ampstats_section FREADS \
     --sample_qc_out 'dir2/plex*/qc'

=head1 DESCRIPTION

This class is a factory for creating npg_qc::autoqc::results::generic
type objects for the output of the samtools ampliconstats command.

=head1 SUBROUTINES/METHODS

=cut

=head2 input_files

A one-member array, a file that is the output of the 'samtools
ampliconstats' command. This attribute is inherited from the parent
and is re-qualified as required.

=cut

has '+input_files' => (
  required => 1,
);

=head2 qc_out

A single output directory. This attribute is inherited from the parent
and is re-qualified as required. Though this attribute can be an array
of multiple output directories, the check will use only one of them -
the first one.

=cut

has '+qc_out' => (
  required => 1,
);

=head2 sample_qc_out

An output directory or a glob expression for directories
for sample (plex) level result JSON files. Optional attribute.

=cut

has 'sample_qc_out' => (
  isa      => 'Str',
  is       => 'ro',
  required => 0,
);

=head2 pp_name

Name of the portable pipeline that produced the file given by
the input_files attribute. Optional attribute.

=cut

has 'pp_name' => (
  isa      => 'Str',
  is       => 'ro',
  required => 0,
  default  => q[ampliconstats],
);

=head2 pp_version

Version of the portable pipeline that produced the file given by
the input_files attribute. Optional attribute.

=cut

has 'pp_version' => (
  isa      => 'Str',
  is       => 'ro',
  required => 0,
);

=head2 ampstats_section

A array of strings, which lists sections of interest in the file
given by the input_files attribute, an optional attribute.

=cut

has 'ampstats_section' => (
  isa      => 'ArrayRef',
  is       => 'ro',
  required => 0,
  default  => sub { return [] },
);

=head2 result

This attribute is inherited from the parent and is changed to be
an array of npg_qc::autoqc::results::* result objects. Different
classes of result objects can be accommodated. By default the
array is empty and cannot be set from the constructor.

=cut

has '+result' => (
  isa       => 'ArrayRef[npg_qc::autoqc::results::base]',
  metaclass => 'NoGetopt',
  init_arg  => undef,
);
sub _build_result {
  return [];
}

=head2 execute

Reads the input file and saves it or some of its data in the result
objects. The first member of the result attribute array is created
for the entity this check object represents, it is an instance of the
npg_qc::autoqc::results::samtools_stats class. Further result objects
are created for as many entities as there were inputs to the samtools
command, they are instances of the npg_qc::autoqc::results::generic
class. For these results the sections of the amplicon stats file
given by the ampstats_section attribute are saved. It should be
possible to convert the names of the input files in the ampliconstats
file to the rpt lists.

If the ampstats_section array is empty, only a samtools_stats result
is generated. There is no validation of the section names, invalid
section names will not lead to an error. This implementation works
correctly only for those sections where there is one line of data
per section per sample.

Does not inherit from the method of the same name in any of
ancestors. 

=cut

sub execute {
  my $self = shift;

  (@{$self->input_files} == 1) or croak 'Only one input file is expected';

  my @data = slurp $self->input_files->[0];

  push @{$self->result}, npg_qc::autoqc::results::samtools_stats->new(
                            composition => $self->composition,
                            filter      => q[ampliconstats],
                            stats       => join q[], @data
                          );

  my $version_line = first_value { $_ =~ /\ASS\s+Samtools[ ]version:/smx } @data;
  my ($st_version) = $version_line =~ /(\S+)\s*\Z/smx;

  my $command_line = first_value { $_ =~ /\ASS\s+Command[ ]line:/smx } @data;
  ($command_line) = $command_line =~ /(ampliconstats.+\S+\.bed)\s/smx;

  my $num_amplicons = first_value { $_ =~ /\ASS\s+Number[ ]of[ ]amplicons:/smx } @data;
  ($num_amplicons) = $num_amplicons =~ /(\d+)\s+\Z/smx;

  my $ampstats_regexp = join q[ | ], @{$self->ampstats_section};

  my $per_product_data = {};
  if ($ampstats_regexp) {
    foreach my $line (@data) {
      ($line =~ /\A($ampstats_regexp)/smx) or next;
      $line =~ s/\s+\Z//smx;
      my @columns = split /\s+/smx, $line;
      my $section_name = shift @columns;
      my $file_name    = shift @columns;
      $per_product_data->{$file_name}->{$section_name} = \@columns;
    }
  }

  my @results = ();
  foreach my $file_name ( keys %{$per_product_data} ) {
    my $result = $self->file_name2result($file_name);
    $result->doc({});
    $result->doc->{'amplicon_stats'} = $per_product_data->{$file_name};
    $result->doc->{'amplicon_stats'}->{'num_amplicons'} = $num_amplicons;
    $result->doc->{'meta'} = $self->get_sample_info(
      st::api::lims->new(rpt_list => $result->composition->freeze2rpt));
    push @results, $result;
  }

  @results = sort { $a->composition->get_component(0)->tag_index <=>
                    $b->composition->get_component(0)->tag_index }
             @results;
  push @{$self->result}, @results;

  $self->_set_common_result_attrs($st_version, $command_line);

  return;
}

=head2 run

This method calls execute() and then serializes the result objects to
JSON files. The first member of the result objects array is saved to
the directory given by the qc_out attribute. If sample_qc_out attribute
is not defined, all other result objects are saved to the same directory
as the first one. If the sample_qc_out attribute is defined and is a
directory, the result objects for samples are saved there. If the
sample_qc_out attribute is a directory glob, an attempt is made to match
the directories represented by a glob with the sample result objects and
to save result objects to their individual directories.

Does not inherit from the method of the same name in any of
ancestors.

=cut

sub run {
  my $self = shift;

  $self->execute();

  (@{$self->result} > 0) or croak 'No results';
  (@{$self->qc_out} == 1) or carp 'Multiple qc_out directories are given, ' .
                                  'only the first one will be used';
  my $qc_out = $self->qc_out->[0];

  # Remove the first result and write it out.
  my $result = shift @{$self->result};
  $result->store($qc_out);

  # Deal with the rest of the results.
  if (not $self->sample_qc_out) {
    for my $r ( @{$self->result} ) {
      $r->store($qc_out);
    }
  } else {
    my @dirs = grep { -d } glob $self->sample_qc_out;
    if (@dirs == 1) {
      $qc_out = $dirs[0];
    }

    for my $r ( @{$self->result} ) {
      my $tag_index = $r->composition->get_component(0)->tag_index;
      my $sample_qc_out = $qc_out;
      if (defined $tag_index and (@dirs > 1)) {
        my @filtered = grep { /\/plex $tag_index\//xms } @dirs;
        (@filtered > 1) and croak "Multiple directory matches for tag $tag_index";
        (@filtered == 0) and croak "No directory match for tag $tag_index";
        $sample_qc_out = $filtered[0];
      }
      $r->store($sample_qc_out);
    }
  }

  return;
}

sub _set_common_result_attrs {
  my ($self, $st_version, $command_line) = @_;

  foreach my $r ( @{$self->result} ) {
    $r->set_info('Check', ref $self);
    $r->set_info('Check_version', $VERSION);
    $command_line and $r->set_info('Samtools_command', $command_line);
    defined $st_version and $r->set_info('Samtools_version', $st_version);
    if ($r->class_name eq 'generic') {
      my @versions = grep { defined and ($_ ne q[]) }
                     ($self->pp_version, $st_version);
      $r->set_pp_info($self->pp_name, join q[ ], @versions);
    }
  }

  return;
}

__PACKAGE__->meta->make_immutable();

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item Readonly

=item Carp

=item Perl6::Slurp

=item List::MoreUtils

=item st::api::lims

=back

=head1 AUTHOR

Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2020 Genome Research Ltd.

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
