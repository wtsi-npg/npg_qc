package npg_qc_viewer::Controller::Illumina;

use Moose;
use MooseX::Types::Moose qw/Int/;

BEGIN { extends 'Catalyst::Controller'; }

our $VERSION  = '0';

##no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc_viewer::Controller::Illumina

=head1 SYNOPSIS

Controller for Illumina qc results.

=head1 DESCRIPTION

Handles the following URLs

  /illumina/runs/*

 where * stands for an integer run identifier.

=head1 SUBROUTINES/METHODS

=head2 iqc

Handles the '/illumina/' part of chained URL (the root).

=cut

sub iqc : PathPart('illumina') : Chained('/') CaptureArgs(0) {
  return;
}

=head2 summary

Handles the 'runs/*' part of chained URL as an endpoint.

=cut

sub summary : PathPart('runs') : Chained('iqc') Args(Int) {
  my ( $self, $c, $id_run ) = @_;

  my @rows = $c->model('MLWarehouseDB')->schema()
               ->resultset('IseqRunLaneMetric')
               ->search({id_run   => $id_run},
                        {order_by => { -asc => 'position'}})
               ->all();
  $c->stash->{'mlwh_lanes'}     = \@rows;
  $c->stash->{'title'}          = qq[Illumina QC results for run $id_run];
  $c->stash->{'template'}       = q[ui_illuminaqc/summary.tt2];
  return;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::Types::Moose

=item Catalyst::Controller

=back

=head1 INCOMPATIBILITIES

Incompatible with namespace::autoclean, which cleans up Int definition.

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 Genome Research Ltd.

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
