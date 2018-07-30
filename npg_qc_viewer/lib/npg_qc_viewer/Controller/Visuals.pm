package npg_qc_viewer::Controller::Visuals;

use Moose;
use namespace::autoclean;
use Try::Tiny;

use npg_qc::autoqc::role::rpt_key;
use npg_qc::autoqc::qc_store::options qw/ $LANES /;

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

=cut

=head2 _render 

Image rendering

=cut
sub _render {
  my ($self, $c, $method, @args) = @_;

  my $image_string;
  try {
    $image_string = $c->model(q[Visuals::Fastqcheck])->$method(@args);
  } catch {
    $c->error($_);
  };

  if ($image_string) {
    $c->res->content_type(q[image/png]);
    $c->res->body( $image_string );
  } else {
    $c->error(qq[image string empty for $method]);
  }

  return;
}


=head2 base 

Action for the base controller path

=cut
sub base :Chained('/') :PathPart('visuals') :CaptureArgs(0) {
  my ($self, $c) = @_;
  return;
}


=head2 fastqcheck

An action for generating a visual representation of a fastqcheck file

=cut
sub fastqcheck :Chained('base') :PathPath('fastqcheck') :Args(0) {
  my ( $self, $c) = @_;

  my $params = $c->request->query_parameters;

  my $rpt_list = $params->{'rpt_list'};
  if (!$rpt_list) {
     $c->error(q['rpt_list' parameter is required]);
     return;
  }
  my $args = npg_qc::autoqc::role::rpt_key->inflate_rpts($rpt_list);
  if (@{$args} > 1) {
    $c->error(q[Fastqcheck visualisation is not available for multiple components]);
    return;
  }
  $args = $args->[0];
  if (defined $args->{'tag_index'}) {
    $c->error(q[Fastqcheck visualisation is not available for plexes]);
    return;
  }
  my $read = $params->{'read'};
  if (!$read) {
    $c->error(q['read' parameter is required]);
    return;
  }

  my $init = {'option' => $LANES};
  $init->{'db_qcresults_lookup'} = $params->{'db_lookup'} ? 1 : 0;
  $init->{'npg_tracking_schema'} = $c->model('NpgDB')->schema();
  $init->{'id_run'} = $args->{'id_run'};
  $init->{'positions'}  = [$args->{'position'}];
  my $query = npg_qc::autoqc::qc_store::query->new($init);

  my $model = $c->model('Check');
  my $paths_list = $params->{'paths_list'};
  if ($paths_list) {
    if (! ref $paths_list) {
      $paths_list = [$paths_list];
    }
  }
  my $content = $paths_list
    ? $model->load_fastqcheck_content_from_path($query, $paths_list, $read)
    : $model->load_fastqcheck_content($query, $read);

  if ($content) {
    $self->_render($c, q[fastqcheck2image], $content, $read);
  } else {
    $c->error('Failed to load fastqcheck content for ' . $query->to_string);
  }

  return;

}

=head2 fastqcheck_legend

An action for generating a legend for a visual representation of fastqcheck files

=cut
sub fastqcheck_legend :Chained('base') :PathPath('fastqcheck_legend') :Args(0) {
  my ( $self, $c) = @_;
  $self->_render($c, q[fastqcheck_legend]);
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

=item Catalyst::Controller

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
