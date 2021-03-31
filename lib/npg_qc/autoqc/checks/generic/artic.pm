package npg_qc::autoqc::checks::generic::artic;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Readonly;
use Carp;
use autodie qw(:all);
use Text::CSV;
use List::Util qw(min max);
use Clone qw(clone);

use npg_tracking::util::types;
use st::api::lims;
use npg_qc::autoqc::results::tag_metrics;

extends qw(npg_qc::autoqc::checks::generic);

## no critic (Documentation::RequirePodAtEnd)

our $VERSION = '0';

Readonly::Scalar my $ARTIC_METRICS_NAME => q[QC summary];

=head1 NAME

npg_qc::autoqc::checks::generic::artic

=head1 SYNOPSIS

Examples of invocation via a qc script:
  
  qc --check generic --spec artic --rpt_list 34761:1 \
     --input_files qc_summary.tsv --qc_out dir \
     --tm_json_file file --pp_name covid --pp_version 33

  # When an attribute is a glob, quote the attribute's value to
  # prevent an early glob expansion. The glob expression for the
  # sample_qc_out attribute should contain the '/plex*/' part.
  qc --check generic --spec artuc --rpt_list 34761:1 \
     --tm_json_file file \
     --input_files_glob '/plexes*/pipeline/qc_summary.tsv' \
     --sample_qc_out 'dir2/plex*/qc'

=head1 DESCRIPTION

This class is a factory for creating npg_qc::autoqc::results::generic
type objects for the output of the
L<ncov2019-artic-nf|https://github.com/wtsi-team112/ncov2019-artic-nf>
pipeline. It captures the QC summary, which is produced by this pipeline.

Ideally, this check should run per lane and should be given
input_file_glob for it to locate input data and qc_out_summary
directory glob to fan out result JSON files one per directory. If the
check is run in this manner, it is able to add information about
negative controls to results for real samples and positive controls.

Setting the input_files array attribute is an alternative way of
providing input, in this case the value of the input_file_glob
attribute is ignored.

If the qc_out_summary attribute is not set and the qc_out attribute
is set, all output will go to the latter directory.

The tm_json_file attribute gives a path to the tag metrics autoqc
result JSON file, which provides information about the content of the
pool and the number of reads in the input to the ncov2019-artic-nf
pipeline. The ncov2019-artic-nf might not produce the QC summary for
every sample of the pool, this might be due to low or zero number of input
reads. Information in the tag metrics is used to fill the gaps so that
the check produces a result object for each sample of the pool. This
is also true if at run time the glob is resolved to an empty list of
files.

This class is a re-implementation, the original implementation was
available in the bin/npg_autoqc_generic4artic script of the same
git package.

=head1 SUBROUTINES/METHODS

=cut

=head2 tm_json_file

A path to a JSON file serialization of the tag_metrics autoqc
result object for teh same lane and run this object belongs to.
A required attribute, should resolve to an existing readable
file at run time.

=cut

has 'tm_json_file' => (
  isa      => 'NpgTrackingReadableFile',
  is       => 'ro',
  required => 1,
);

=head2 input_files_glob

An optional attribute to set a glob expression for check input files,
QC summary outputs of the ncov2019-artic-nf pipeline.

=cut

has 'input_files_glob' => (
  isa       => 'Str',
  is        => 'ro',
  predicate => '_has_input_files_glob',
  required  => 0,
);

=head2 input_files

Array reference with paths of input files for this check. An optional
lazily built attribute inherited from npg_qc::autoqc::checks::check,
the method for building it is overwritten here to search for input
files using a glob expression in the input_files_glob attribute. 

=cut

has '+input_files' => (
  isa       => 'ArrayRef[NpgTrackingReadableFile]',
);
sub _build_input_files {
  my $self = shift;

  $self->_has_input_files_glob or croak 'input_files_glob should be defined';
  ($self->input_files_glob eq q[]) and croak
    'input_files_glob value cannot be an empty string';
  my @files = glob $self->input_files_glob;
  # Retrieving no files is not an error!
  carp sprintf '%s file%s found using glob %s',
    (@files ? scalar @files : 'No'),
    (@files == 1 ? ' was' : 's were'), $self->input_files_glob;
  return \@files;
}

=head2 result

This lazily built attribute is inherited from the parent and is changed
to be an array of npg_qc::autoqc::results::generic result objects. A result
object is created for each tag index in a pool (lane). The result objects
which have a corresponding input file, have the ncov2019-artic-nf QC summary,
other result objects do not have this information.

The array is sorted by tag index in acsending order.

=cut

has '+result' => (
  isa       => 'ArrayRef[npg_qc::autoqc::results::generic]',
);
sub _build_result {
  my $self = shift;

  my @results = grep { $_ }
                map { $self->_summary2result_obj($_) }
                @{$self->input_files};
  $self->_add_missing_results(\@results);
  @results = sort { $a->composition->get_component(0)->tag_index <=>
                    $b->composition->get_component(0)->tag_index } @results;

  return \@results;
}

=head2 execute

=cut

sub execute {
  my $self = shift;

  # Set those attributes of the result objects, which do not depend of the
  # values of attributes in other result objects.  
  foreach my $result ( @{$self->result} ) {
    # set LIMs metadata
    $result->doc->{'meta'} = $self->get_sample_info(
      st::api::lims->new(rpt_list => $result->composition->freeze2rpt));
    # set input read count
    my $ti = $result->composition->get_component(0)->tag_index;
    defined $ti or croak 'Lane level result is not expected';
    defined $self->_reads_count->{$ti} or croak
      sprintf 'Input read count for tag %i is not in tag metrics %s',
              $ti, $self->tm_json_file;
    $result->doc->{'meta'}->{'num_input_reads'} = $self->_reads_count->{$ti};
    # set info about this check
    $self->set_common_result_attrs($result);
  }

  # For each sample, provide information about other samples or controls;
  # this will be used in roboQC assessment.

  my $re = qr/negative/smxi;
  # Assign zero where we have no artic result, which would be normal
  # if the number of input reads is very low or zero.
  my $max_count_negative =
    max
    map  { $_->doc->{$ARTIC_METRICS_NAME}->{'num_aligned_reads'} || 0 }
    grep { $_->doc->{'meta'}->{'sample_type'} =~ $re }
    @{$self->result};
  defined $max_count_negative or carp 'No negative controls in this lane';

  $re = qr/positive|real/smxi;
  # Consider artic passes only.
  my $min_count_real =
    min
    map  { $_->doc->{$ARTIC_METRICS_NAME}->{'num_aligned_reads'} }
    grep { $_->doc->{$ARTIC_METRICS_NAME}->{'qc_pass'} eq 'TRUE' }
    grep { defined $_->doc->{$ARTIC_METRICS_NAME} }
    grep { $_->doc->{'meta'}->{'sample_type'} =~ $re }
    @{$self->result};

  foreach my $result ( @{$self->result} ) {
    defined $max_count_negative and $result->doc->{'meta'}
      ->{'max_negative_control_filtered_read_count'} = $max_count_negative;
    defined $min_count_real and $result->doc->{'meta'}
      ->{'min_artic_passed_filtered_read_count'} = $min_count_real;
  }

  return;
}

=head2 run

This method executes the check and then calls the inherited
store_fanned_results method method to serialize the result objects
to JSON files.

=cut

sub run {
  my $self = shift;

  $self->execute();
  @{$self->result} or croak 'Result objects array is empty';
  $self->store_fanned_results();

  return;
}

has '_reads_count' => (
  isa        => 'HashRef',
  is         => 'ro',
  lazy_build => 1,
);
sub _build__reads_count {
  my $self = shift;

  ($self->composition->num_components == 1) or croak
    'Cannot get deplexing stats for a multi-component composition';

  my $comp = $self->composition->get_component(0);

  # Try to parse the tag metrics file.
  my $tm = npg_qc::autoqc::results::tag_metrics->load($self->tm_json_file);
  # Is it for the correct lane?
  my $tmc = $tm->composition->get_component(0);
  ($tmc->id_run == $comp->id_run) and ($tmc->position == $comp->position) or
    croak $self->tm_json_file . ' does not correspond to ' . $comp->freeze2rpt;

  return $tm->reads_pf_count;
}

sub _add_missing_results {
  my ($self, $results) = @_;

  my %available = map { $_->composition->get_component(0)->tag_index => 1 }
                  @{$results};

  my $master_ref = $self->inflate_rpts($self->rpt_list)->[0];
  delete $master_ref->{tag_index};

  for my $ti ( keys %{$self->_reads_count} ) {
    $ti or next; # not interested in tag zero
    $available{$ti} and next;
    my $ref = clone($master_ref);
    $ref->{tag_index} = $ti;
    my $composition = npg_tracking::glossary::composition->new(components =>
      [npg_tracking::glossary::composition::component::illumina->new($ref)]);
    push @{$results}, npg_qc::autoqc::results::generic->new(
                        composition => $composition, doc => {});
  }

  return;
}

sub _summary2result_obj {
  my ($self, $file) = @_;

  open my $fh, q[<], $file;
  my $csv = Text::CSV->new();
  my $line = $csv->getline($fh);
  $line or return; # empty file
  $csv->column_names($line);
  $line = $csv->getline_hr($fh);
  close $fh;

  my $file_name_root = $line->{'sample_name'};
  $file_name_root or croak 'No file name in sample_name column';
  my $result = $self->file_name2result($file_name_root);
  $result->doc({$ARTIC_METRICS_NAME => $line});

  return $result;
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

=item Text::CSV

=item List::Util

=item Clone

=item autodie

=item npg_tracking::util::types

=item st::api::lims

=item npg_qc::autoqc::results::tag_metrics

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
