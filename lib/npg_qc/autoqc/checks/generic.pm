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

=head2 result

A lazy_built attribute, an instance of npg_qc::autoqc::results::generic
class, corresponding to the same entity as this check object.
Inherited from npg_qc::autoqc::checks::check .

=cut

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

This method is a stab, it does not provide any functionality and
is retained for compatibility with the autoqc framework. It does
not extend the parent's execute() method.

=cut

sub execute {
  return;
}

=head2 run

This method is a simple wrapper around a routine for serializing
a single result object to JSON and saving the JSON string to a file
system. The qc_out attribute of this object is used as a directory
for creating a JSON file. An error might be raised if the qc_out
attribute is not set by the caller. The method does not extent the
parent's run() method.

=cut

sub run {
  my $self = shift;
  $self->result->store($self->qc_out->[0]);
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
