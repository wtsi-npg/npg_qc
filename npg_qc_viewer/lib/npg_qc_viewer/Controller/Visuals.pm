package npg_qc_viewer::Controller::Visuals;

use Moose;
use namespace::autoclean;
use Try::Tiny;
use List::MoreUtils qw/any/;

use npg_tracking::glossary::composition::factory::rpt_list;

BEGIN { extends 'Catalyst::Controller' }

our $VERSION  = '0';
## no critic (Documentation::RequirePodAtEnd Subroutines::ProhibitBuiltinHomonyms)

=head1 NAME

npg_qc_viewer::Controller::Visuals - Catalyst Controller for rendering images on a fly

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

Catalyst Controller.

=head1 SUBROUTINES/METHODS

=head2 base 

Action for the base controller path

=cut

sub base :Chained('/') :PathPart('visuals') :CaptureArgs(0) {
  my ($self, $c) = @_;
  return;
}

=head2 qualmap

An action for generating quality by cycle heatmaps

=cut

sub qualmap :Chained('base') :PathPath('qualmap') :Args(0) {
  my ( $self, $c) = @_;

  my $params = $c->request->query_parameters;

  my $rpt_list = $params->{'rpt_list'};
  if (!$rpt_list) {
    $c->error(q['rpt_list' parameter is required]);
    return;
  }
  my $read = $params->{'read'};
  if (!$read) {
    $c->error(q['read' parameter is required]);
    return;
  }

  my $result;
  try {
    my $file_path = $params->{'file_path'};
    my $model = $c->model('Check');
    if ($file_path) {
      $result = $model->json_file2result_object($file_path);
    } else {
      if ($model->use_db) {
        my $composition = npg_tracking::glossary::composition::factory::rpt_list
                          ->new(rpt_list => $rpt_list)
                          ->create_composition();
        my @rows = $model->qc_schema->resultset('SamtoolsStats')
                         ->search_via_composition([$composition])->all();
        if (@rows) {
          $result = $rows[0]->result4visuals(\@rows);
        }
      }
    }
  } catch {
    $c->error($_);
  };

  if ($result) {
    $self->_render($c, q[data2image], $result, $read);
  } else {
    $c->error("Failed to load samtools stats result object for $rpt_list");
  }

  return;
}

=head2 qualmap_legend

An action for generating a legend for quality by cycle heatmaps

=cut

sub qualmap_legend :Chained('base') :PathPath('qualmap_legend') :Args(0) {
  my ( $self, $c) = @_;
  $self->_render($c, q[legend]);
  return;
}

sub _render {
  my ($self, $c, $method, @args) = @_;

  try {
    $c->res->content_type(q[image/png]);
    $c->res->body($c->model(q[QualityHeatmap])->$method(@args));
  } catch {
    $c->error($_);
  };

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

=item namespace::autoclean

=item Try::Tiny

=item List::MoreUtils

=item Catalyst::Controller

=item npg_tracking::glossary::composition::factory::rpt_list

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 Genome Research Ltd.

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
