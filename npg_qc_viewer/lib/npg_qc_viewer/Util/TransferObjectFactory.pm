package npg_qc_viewer::Util::TransferObjectFactory;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Carp;

use npg_qc_viewer::Util::TransferObject;

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc_viewer::Util::TransferObjectFactory

=head1 SYNOPSIS

  my $factory = npg_qc_viewer::Util::TransferObjectFactory->new(
     product_metrics_row => $product_metrics,
     lane_level          => 1);
  my $lane_transfer_object = $factory->create_object();
  $factory->lane_level(0);
  my $plex_transfer_object = $factory->create_object();

=head1 DESCRIPTION

A factory to generate npg_qc_viewer::Util::TransferObject objects.

=head1 SUBROUTINES/METHODS

=head2 product_metrics_row

=cut
has 'product_metrics_row'    => (
  isa      => 'WTSI::DNAP::Warehouse::Schema::Result::IseqProductMetric',
  is       => 'ro',
  required => 1,
);

=head2 is_pool

=cut
has 'is_pool'    => (
  isa      => 'Bool',
  is       => 'ro',
);

=head2 is_plex

=cut
has 'is_plex'    => (
  isa      => 'Bool',
  is       => 'ro',
);

=head2 not_qcable

=cut
has 'not_qcable'    => (
  isa      => 'Bool',
  is       => 'ro',
);

=head2 BUILD

=cut
sub BUILD {
  my $self = shift;
  if ($self->is_pool && $self->is_plex) {
    croak 'An entity cannot be both pool and plex';
  }
  return;
}

=head2 create_object

Returns npg_qc_viewer::Util::TransferObject type object

=cut
sub create_object {
  my $self = shift;
  my $init = $self->_add_npg_data();
  $init = $self->_add_lims_data($init);
  return npg_qc_viewer::Util::TransferObject->new($init);
}

sub _add_npg_data {
  my $self = shift;

  my $product_metric = $self->product_metrics_row();
  my $init_values = {};
  $init_values->{'id_run'}         = $product_metric->id_run;
  $init_values->{'position'}       = $product_metric->position;
  $init_values->{'num_cycles'}     = $product_metric->iseq_run_lane_metric->cycles;
  $init_values->{'time_comp'}      = $product_metric->iseq_run_lane_metric->run_complete;
  if ($self->is_plex) {
    $init_values->{'tag_index'}    = $product_metric->tag_index;
    $init_values->{'tag_sequence'} = $product_metric->tag_sequence4deplexing;
  }

  return $init_values;
}

sub _add_lims_data {
  my ($self, $init_values) = @_;

  my $flowcell = $self->product_metrics_row->iseq_flowcell;
  $init_values ||= {};
  $init_values->{'is_pool'}          = $self->is_pool;
  $init_values->{'lims_live'}        = 1;
  $init_values->{'is_control'}       = 0;
  $init_values->{'rnd'}              = 0;

  if ( defined $flowcell ) {

    $init_values->{'legacy_library_id'} = $flowcell->legacy_library_id;
    $init_values->{'rnd'}               = $flowcell->is_r_and_d ? 1 : 0;
    $init_values->{'is_control'}        = $flowcell->is_control ? 1 : 0;
    $init_values->{'entity_id_lims'}    = $flowcell->entity_id_lims;
    $init_values->{'lims_live'}         = $flowcell->from_gclp ? 0 : 1;

    if ($self->is_pool) {
      $init_values->{'id_library_lims'} = $flowcell->id_pool_lims;
    } else {
      for my $attr (qw/ study_name
                        sample_id
                        sample_name
                        sample_supplier_name
                        id_library_lims
                      /) {
        $init_values->{$attr} = $flowcell->$attr;
      }
    }
  }

  $init_values->{'instance_qc_able'} =
    $self->not_qcable
    ? 0
    : $self->qc_able($init_values->{'is_control'}, $init_values->{'tag_index'});

  return $init_values;
}

=head2 qc_able

Class method, returns true if the entity is subject to manual QC.

 my $is_control = 0;
 my $tag_index = 5;
 my $flag = $factory->qc_able($is_control, $tag_index);

 $tag_index = undef;
 $flag = $factory->qc_able($is_control, $tag_index);

=cut
sub qc_able {
  my ($self, $is_control, $tag_index) = @_;
  return ($is_control || (defined $tag_index && $tag_index == 0) ) ? 0 : 1;
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

=item npg_qc_viewer::Util::TransferObject

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 Genome Research Ltd.

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
