package npg_qc_viewer::Model::MLWarehouseDB;

use Moose;
use namespace::autoclean;
use Carp;

BEGIN { extends 'Catalyst::Model::DBIC::Schema' }

our $VERSION  = '0';

## no critic (Documentation::RequirePodAtEnd)

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

=head2 search_product_metrics_by_run

Search product metrics by id_run (and position if provided).

=cut
sub search_product_metrics_by_run {
  my ($self, $id_run, $position) = @_;

  if(!defined $id_run) {
    croak q[Id run not defined when querying metrics by id_run];
  }

  my $where = {'me.id_run' => $id_run};
  if(defined $position) {
    $where->{'me.position'} = $position;
  }

  my $rs = $self->resultset('IseqProductMetric')->
             search($where, {
               prefetch => ['iseq_run_lane_metric', 'iseq_flowcell' ],
               join => [ 'iseq_run_lane_metric', 'iseq_flowcell' ]
             });

  return $rs;
}

=head2 search_library_lims_by_id

Search library by new id library in lims.

=cut
sub search_library_lims_by_id {
  my ($self, $id_library_lims) = @_;

  if (!defined $id_library_lims) {
    croak q[Id library lims not defined when querying library lims];
  }

  my $where = { 'iseq_flowcell.id_library_lims' => $id_library_lims,
                'me.tag_index' => [ undef, { q[!=], 0 }],};

  my $rs = $self->resultset('IseqProductMetric')->
             search($where, {
               join => ['iseq_flowcell'],
               '+columns'  => ['me.id_run',
                               'me.position',
                               'me.tag_index',
                               'iseq_flowcell.id_library_lims',
                               'iseq_flowcell.legacy_library_id',
               ],
               group_by => qw[me.id_run me.position me.tag_index iseq_flowcell.id_library_lims iseq_flowcell.legacy_library_id],
  });

  return $rs;
}

=head2 search_library_lims_by_sample

Search for library by sample id in lims

=cut
sub search_library_lims_by_sample {
  my ($self, $id_sample_lims) = @_;

  if (!defined $id_sample_lims) {
    croak q[Id sample lims not defined when querying for library lims];
  }

  my $where = { 'sample.id_sample_lims' => $id_sample_lims,};

  my $rs = $self->resultset('IseqProductMetric')->
             search($where, {
               join => [{'iseq_flowcell' => 'sample'}],
               '+columns'  => ['me.id_run',
                               'me.position',
                               'me.tag_index',
                               'iseq_flowcell.id_library_lims',
                               'iseq_flowcell.legacy_library_id',
               ],
               group_by => qw[me.id_run
                              me.position
                              me.tag_index
                              iseq_flowcell.id_library_lims
                              iseq_flowcell.legacy_library_id],
  });

  return $rs;
}

=head2 search_sample_lims_by_id

Search sample by id

=cut
sub search_sample_lims_by_id {
  my ($self, $id_sample_lims) = @_;

  if (!defined $id_sample_lims) {
    croak q[Id sample lims not defined when querying sample lims];
  };

  my $rs = $self->resultset('Sample')->search(
    {id_sample_lims => $id_sample_lims,}
  );

  return $rs;
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
