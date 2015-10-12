package npg_qc_viewer::Util::TransferObjectFactory;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use npg_qc_viewer::Util::TransferObject;

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc_viewer::Util::TransferObjectFactory

=head1 SYNOPSIS

  my $factory = npg_qc_viewer::Util::TransferObjectFactory->new(
     product_metrics_row => $product_metrics,
     qc_schema           => $qc_schema,
     lane_level          => 1);
  my $lane_transfer_object = $factory->create_object();
  $factory->lane_level(0);
  my $plex_transfer_object = $factory->create_object();

=head1 DESCRIPTION

A factory to generate npg_qc_viewer::Util::TransferObject objects.

=head1 SUBROUTINES/METHODS

=head2 qc_schema

=cut
has 'qc_schema'   => (
  isa      => 'Object',
  is       => 'ro',
  required => 1,
);

=head2 product_metrics_row

=cut
has 'product_metrics_row'    => (
  isa      => 'WTSI::DNAP::Warehouse::Schema::Result::IseqProductMetric',
  is       => 'ro',
  required => 1,
);

=head2 lane_level

=cut
has 'lane_level'    => (
  isa      => 'Bool',
  is       => 'rw',
  required => 1,
);

=head2 create_object

=cut
sub create_object {
  my $self = shift;

  my $values = {};
  $self->_add_npg_data($values);
  $self->_add_lims_data($values);
  my $to = npg_qc_viewer::Util::TransferObject->new($values);
  $self->_get_mqc_from_qc($to);

  return $to;
}

sub _get_mqc_from_qc {
  my ($self, $to) = @_;

  if ($self->lane_level && defined $to->manual_qc) {
    return;
  }

  my $wh_mqc = $to->manual_qc();
  $to->unset_manual_qc();

  if ( $to->tag_index ) { # tag zero is not qc-ed
    my $lib_mqc_row = $self->qc_schema->resultset('MqcLibraryOutcomeEnt')->search(
      {id_run    => $to->id_run,
       position  => $to->position,
       tag_index => $to->tag_index})->next();
    if ( $lib_mqc_row ) {
      if ( $lib_mqc_row->has_final_outcome ) {
        _set_mqc_value($lib_mqc_row, $to);
      } else {
        if ( defined $wh_mqc && $wh_mqc == 0 ) {
          $to->manual_qc(0);
        }
      }
    }
  } else {
    if ( !defined $to->tag_index ) {
      my $lane_mqc_row = $self->qc_schema->resultset('MqcOutcomeEnt')->search(
        {id_run    => $to->id_run,
         position  => $to->position})->next();
      if ($lane_mqc_row && $lane_mqc_row->has_final_outcome) {
        _set_mqc_value($lane_mqc_row, $to);
      }
    }
  }
  return;
}

sub _set_mqc_value {
  my ($row, $to) = @_;
  $to->manual_qc($row->is_accepted ? 1 : 0);
  return;
}

sub _add_npg_data {
  my ($self, $values) = @_;

  my $product_metric = $self->product_metrics_row();
  $values->{'id_run'}       = $product_metric->id_run;
  $values->{'position'}     = $product_metric->position;
  $values->{'tag_sequence'} = $product_metric->tag_sequence4deplexing;
  $values->{'num_cycles'}   = $product_metric->iseq_run_lane_metric->cycles;
  $values->{'time_comp'}    = $product_metric->iseq_run_lane_metric->run_complete;
  if (!$self->lane_level) {
    $values->{'tag_index'}  = $product_metric->tag_index;
  }
  return;
}

sub _add_lims_data {
  my ($self, $values) = @_;

  my $flowcell = $self->product_metrics_row->iseq_flowcell;
  if ( defined $flowcell ) {
    $values->{'id_library_lims'}      = $flowcell->id_library_lims;
    $values->{'legacy_library_id'}    = $flowcell->legacy_library_id;
    $values->{'id_pool_lims'}         = $flowcell->id_pool_lims;
    $values->{'rnd'}                  = $flowcell->is_r_and_d;
    $values->{'manual_qc'}            = $flowcell->manual_qc;
    $values->{'is_gclp'}              = $flowcell->from_gclp;
    $values->{'entity_id_lims'}       = $flowcell->entity_id_lims;
    $values->{'study_name'}           = $flowcell->study_name;
    $values->{'id_sample_lims'}       = $flowcell->sample_id;
    $values->{'sample_name'}          = $flowcell->sample_name;
    $values->{'supplier_sample_name'} = $flowcell->sample_supplier_name;
    $values->{'manual_qc'}            = $flowcell->manual_qc;
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

=item npg_qc_viewer::Util::TransferObject

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 Genome Research Ltd.

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
