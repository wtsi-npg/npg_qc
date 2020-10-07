package npg_qc::autoqc::checks::generic;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use st::api::lims;
use Carp;

use npg_tracking::glossary::moniker;
use npg_tracking::glossary::rpt;
use npg_tracking::glossary::composition::factory::rpt_list;
use npg_qc::autoqc::results::generic;

extends qw(npg_qc::autoqc::checks::check);

## no critic (Documentation::RequirePodAtEnd)
our $VERSION = '0';

=head1 NAME

npg_qc::autoqc::checks::generic

=head1 SYNOPSIS

=head1 DESCRIPTION

This class is a factory for creating npg_qc::autoqc::results::generic
type objects. It does not provide any fuctionality in its execute()
method. For convenience it provides access to LIMS data via its
lims attribute.  

=head1 SUBROUTINES/METHODS

=head2 sample_qc_out

An output directory or a glob expression for directories
for sample (plex) level result JSON files, an optional attribute.

=cut

has 'sample_qc_out' => (
  isa      => 'Str',
  is       => 'ro',
  required => 0,
);

=head2 pp_name

Name of the portable pipeline that produced input data for this
check, an optional attribute.

=cut

has 'pp_name' => (
  isa      => 'Str',
  is       => 'ro',
  required => 0,
  default  => q[ampliconstats],
);

=head2 pp_version

Version of the portable pipeline that produced input data for
this check, an optional attribute.

=cut

has 'pp_version' => (
  isa      => 'Str',
  is       => 'ro',
  required => 0,
);

=head2 result

This attribute is inherited from the parent and is changed to be
an array of npg_qc::autoqc::results::* result objects. Different
classes of result objects can be accommodated. By default the
array is empty and cannot be set from the constructor.

=cut

has '+result' => (
  isa       => 'ArrayRef[npg_qc::autoqc::results::base]',
  init_arg  => undef,
);
sub _build_result {
  return [];
}

=head2 lims

A lazy-built attribute, the st::api::lims object corresponding
to this object's rpt_list attribute. 

=cut

has 'lims' => (
  isa        => 'st::api::lims',
  is         => 'ro',
  lazy_build => 1,
);
sub _build_lims {
  my $self = shift;
  return st::api::lims->new(rpt_list => $self->rpt_list);
}

=head2 execute

This method is a stub, it does not provide any functionality and
is retained for compatibility with the autoqc framework. It does
not extend the parent's execute() method.

=cut

sub execute {
  return;
}

=head2 run

This method is a stub, it does not provide any functionality and
is retained for compatibility with the autoqc framework. It does
not extend the parent's run() method.

=cut

sub run {
  return;
}

=head2 get_sample_info

Returns a hash reference with sample information about product.
Either a st::api::lims type object corresponding to the product
should be used as an argument or the lims attribute of this
object is used.

  my $sh = $obj->get_sample_info($lims);
  # or
  $sh = $obj->get_sample_info(); # $self->lims is assumed 

  print $sh->{supplier_sample_name}; # if this name is
                                     # not defined, the key
                                     # will be absent
  print $sh->{sample_type}; # possible values:
                            # real_sample,
                            # negative_control,
                            # positive_control

=cut

sub get_sample_info {
  my ($self, $lims) = @_;

  $lims ||= $self->lims;
  my $h = {};

  my $sname = $lims->sample_supplier_name();
  if (!$sname) {
    # Not exiting here, the supplier name is often not set for R&D samples.
    # Be careful with the source of LIMS data, the supplier name is not set
    # in XML feeds. Use a samplesheet!
    $sname = q[];
    carp 'Sample supplier name is not defined for ' . $lims->to_string;
  } else {
    $h->{'supplier_sample_name'} = $sname;
  }

  my $is_control   = $lims->sample_is_control;
  my $control_type = $lims->sample_control_type;
  (not $is_control) and $control_type and croak
    "Control type '$control_type' is set for a non-control sample '$sname'";
  $is_control and (not $control_type) and croak
    "Control type is not set for a control sample '$sname'";

  $h->{'sample_type'} =
    $is_control ? $control_type . q[_control] : 'real_sample';

  return $h;
}

=head2 file_name2result

A factory method to create a npg_qc::autoqc::results:generic
object that corresponds to the argument file name. Can be used as either
class or instance method. Uses parse_file_name method from the
npg_tracking::glossary::moniker class and is, therefore, subject to
the same limitations and that parser.

  my $result = $obj->file_name2result_object('23_1#4.bam');
  print $result->rpt_list; # 23:1:4
  print ref $result; # npg_qc::autoqc::results:generic

=cut

sub file_name2result {
  my ($package, $file_name) = @_;

  $file_name or croak 'File name argument should be given';
  my $h = npg_tracking::glossary::moniker->parse_file_name($file_name);
  my $rpt = npg_tracking::glossary::rpt->deflate_rpt($h);
  my $c = npg_tracking::glossary::composition::factory::rpt_list
            ->new(rpt_list=>$rpt)->create_composition();
  return npg_qc::autoqc::results::generic->new(composition => $c);
}

=head2 set_common_result_attrs

Sets the check name and version and pipeline name and version
information of the result object.

=cut

sub set_common_result_attrs {
  my ($self, $result, $version_extra) = @_;

  $result->set_info('Check', ref $self);
  $result->set_info('Check_version', $VERSION);
  if ($result->class_name eq 'generic') {
    my @versions = grep { defined and ($_ ne q[]) }
                   ($self->pp_version, $version_extra);
    $result->set_pp_info($self->pp_name, join q[ ], @versions);
  }

  return;
}

=head2 store_fanned_results

This method serializes the objects in the result array attribute to JSON files.

If the sample_qc_out attribute is not defined or the file glob resolves to
no existing directories, and the qc_out attribute is set, all JSON files are
saved to the directory given by the latter attribute.

If the sample_qc_out defines a directory or a file glob that resolves to a
single directory, all JSON files are saved to that directory.

If the sample_qc_out attribute is a directory glob, which resolves to multiple
directories an attempt is made to match the sample result objects with the
the directories and to save result objects to their individual directories.

An empty result array is not considered as an error.

=cut

sub store_fanned_results {
  my $self = shift;

  if (@{$self->result} == 0) {
    # Not an error!
    carp 'No results, nothing to store';
    return;
  }

  my $qc_out;

  if ($self->has_qc_out()) {
    (@{$self->qc_out} == 1) or carp 'Multiple qc_out directories are given, ' .
                                    'only the first one will be used';
    $qc_out = $self->qc_out->[0];
  }

  if (not $self->sample_qc_out) {
    $qc_out or croak 'Either qc_out  or sample_qc_out attribute should be set';
    for my $r ( @{$self->result} ) {
      $r->store($qc_out);
    }
  } else {
    # Our fall-back position is either a single output of the glob or
    # a pre-set qc_out attribute.
    my @dirs = grep { -d } glob $self->sample_qc_out;
    (@dirs or $qc_out) or croak 'No existing directory for output is found';
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

=item Carp

=item st::api::lims

=item npg_tracking::glossary::moniker

=item npg_tracking::glossary::rpt

=item npg_tracking::glossary::composition::factory::rpt_list

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
