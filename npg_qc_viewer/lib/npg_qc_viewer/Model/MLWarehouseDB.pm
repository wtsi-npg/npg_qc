package npg_qc_viewer::Model::MLWarehouseDB;

use Moose;
use namespace::autoclean;
use Carp;
use Readonly;

BEGIN { extends 'Catalyst::Model::DBIC::Schema' }

our $VERSION  = '0';

Readonly::Scalar our $HASH_KEY_QC_TAGS     => q[qc_tags];
Readonly::Scalar our $HASH_KEY_NON_QC_TAGS => q[non_qc_tags];

## no critic (Documentation::RequirePodAtEnd)

=begin stopwords

lims

=end stopwords

=head1 NAME

npg_qc_viewer::Model::MLWarehouseDB

=head1 SYNOPSIS

=head1 DESCRIPTION

Catalyst::Model::DBIC::Schema Model using schema WTSI::DNAP::Warehouse::Schema

=head1 SUBROUTINES/METHODS

=cut

__PACKAGE__->config(
  schema_class => 'WTSI::DNAP::Warehouse::Schema',
  connect_info => [], #a fall-back position if connect_info is not defined in the config file
);

=head2 search_product_metrics

Search product metrics by where conditions (id_run, position, tag_index).

=cut
sub search_product_metrics {
  my ($self, $run_details) = @_;

  if(!defined $run_details){
    croak q[Conditions were not provided for search];
  }

  if(!defined $run_details->{'id_run'}) {
    croak q[Id run not defined when querying metrics by me.id_run];
  }

  my $resultset = $self->resultset('IseqProductMetric');
  my $cs_alias = $resultset->current_source_alias;

  my $where = {};
  foreach my $key (keys %{$run_details}) {
    $where->{$cs_alias . q[.] . $key} = $run_details->{$key};
  }

  my $rs = $resultset->
             search($where, {
               prefetch => ['iseq_run_lane_metric', {'iseq_flowcell' => ['study', 'sample']}],
               order_by => qw[ me.id_run me.position me.tag_index ],
               cache    => 1,
             },);

  return $rs;
}

=head2 search_product_by_id_library_lims

Search product id library lims.

=cut
sub search_product_by_id_library_lims {
  my ($self, $id_library_lims) = @_;

  if (!defined $id_library_lims) {
    croak q[Id library lims not defined when querying library lims];
  }

  my $where = { 'iseq_flowcell.id_library_lims' => $id_library_lims, };

  return $self->_search_product_by_child_id($where);
}

=head2 search_product_by_id_pool_lims

Search for product by id pool lims.

=cut
sub search_product_by_id_pool_lims {
  my ($self, $id_pool_lims) = @_;

  if (!defined $id_pool_lims) {
    croak q[Id pool lims not defined when querying pool lims];
  }

  my $where = { 'iseq_flowcell.id_pool_lims' => $id_pool_lims, };

  return $self->_search_product_by_child_id($where);
}

=head2 search_product_by_sample_id

Search product by id sample lims

=cut
sub search_product_by_sample_id {
  my ($self, $id_sample_lims) = @_;

  if (!defined $id_sample_lims) {
    croak q[Id sample lims not defined when querying sample lims];
  };

  my $where = { 'sample.id_sample_lims' => $id_sample_lims, };

  return $self->_search_product_by_child_id($where);
}

sub _search_product_by_child_id {
#  Search product by id lims in one of the children tables. The where clause
#  should be defined as a hash with the condition to query the relationship
#  Product->Flowcell->Sample.
#
#  my $where = { 'id_sample_lims' => $id_sample_lims };
#  $rs = $c->model('MLWarehouseDB')->_search_product_by_child_id($where);

  my ($self, $where) = @_;

  if (!defined $where) {
    croak q[Condition for id lims not defined when querying product by children id];
  };

  my $rs = $self->resultset('IseqProductMetric')->
                    search($where, {
                    prefetch => {'iseq_flowcell' => 'sample'},
                    join     => {'iseq_flowcell' => 'sample'},
                    cache    => 1,
  });

  return $rs;
}

=head2 search_sample_by_sample_id

Search sample by id sample lims

=cut
sub search_sample_by_sample_id {
  my ($self, $id_sample_lims) = @_;

  if (!defined $id_sample_lims) {
    croak q[Id sample lims not defined when querying sample lims];
  };

  my $resultset = $self->resultset('Sample');
  my $cs_alias = $resultset->current_source_alias;

  my $where = { $cs_alias . '.id_sample_lims' => $id_sample_lims, };

  my $rs = $self->resultset('Sample')->
                    search($where, {
                    cache    => 1,
  });

  return $rs;
}

=head2 fetch_tag_index_array_for_run_position

  Search for tag indexes associated with a run, position and return them as
  an array. It does the search explicitely excluding tag_index = 0 and 
  entity_type = 'library_index_spike'. Croaks if there is no data in LIMS for
  the parameters.

=cut
sub fetch_tag_index_array_for_run_position {
  my ($self, $id_run, $position) = @_;

  if(!defined $id_run) {
    croak q[Id run is required when searching for tag_indexes but not defined];
  }
  if(!defined $position) {
    croak q[Position is required when searching for tag_indexes but not defined];
  }

  my $resultset = $self->resultset('IseqProductMetric');
  my $cs_alias = $resultset->current_source_alias;

  my $where = {
    $cs_alias . '.id_run'     => $id_run,
    $cs_alias . '.position'   => $position,
    $cs_alias . '.tag_index'  => { q[!=], undef },
  };

  my $rs = $resultset->search($where, {
             prefetch => ['iseq_run_lane_metric', 'iseq_flowcell'],
             order_by => qw[ me.id_run me.position me.tag_index ],
             cache    => 1,
  });

  #TODO Should this go outside (meaning an extra query)?
  if ($rs->count != 0) {
    croak q[Error: No LIMS data for this run/position.];
  }

  my $tags = {};

  my $where_ti = {
    $cs_alias . '.tag_index' => { q[!=] => 0 },
    'entity_type'            => { q[!=] => 'library_indexed_spike' },
  };
  my $qc_tags = $self->_get_from_rs_as_array($rs, $where_ti);

  $where_ti = {
    -or => [
      $cs_alias . '.tag_index' => { q[=] => 0 },
      'entity_type'            => { q[=] => 'library_indexed_spike' },
    ],
  };
  my $non_qc_tags = $self->_get_from_rs_as_array($rs, $where_ti);

  $tags->{$HASH_KEY_QC_TAGS}     = $qc_tags;
  $tags->{$HASH_KEY_NON_QC_TAGS} = $non_qc_tags;

  return $tags;
}

sub _get_from_rs_as_array {
  my ($self, $rs, $where) = @_;

  my $temp_array = [];

  my $rs1 = $rs->search($where);
  while(my $prod = $rs1->next) {
    my $tag_index = $prod->tag_index;
    push @{$temp_array}, $tag_index;
  }

  return $temp_array;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Catalyst::Model::DBIC::Schema

=item WTSI::DNAP::Warehouse::Schema

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David Jackson

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 Genome Research Ltd.

This file is part of NPG software.

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
