package npg_qc_viewer::Controller::Visuals;

use Moose;
use namespace::autoclean;
use English qw(-no_match_vars);

BEGIN { extends 'Catalyst::Controller' }

our $VERSION  = '0';
## no critic (Documentation::RequirePodAtEnd Subroutines::ProhibitBuiltinHomonyms)

=head1 NAME

npg_qc_viewer::Controller::Visuals - Catalyst Controller for rendering images on a fly

=head1 VERSION

$Revision: 13084 $

=head1 SYNOPSIS


=head1 DESCRIPTION

Catalyst Controller.

=head1 SUBROUTINES/METHODS

=cut

=head2 _render 

Image rendering

=cut
sub _render {
  my ($self, $c, $method, $args) = @_;

  my $image_string;
  eval {
    $image_string = $c->model(q[Visuals::Fastqcheck])->$method($args);
    1;
  } or do {
    if ($EVAL_ERROR) {
      $c->error($EVAL_ERROR);
      return;
	  }
  };

  if ($image_string) {
    $c->res->content_type(q[image/png]);
    $c->res->body( $image_string );
  } else {
    $c->error(qq[image string empty for $method])
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

  my $model = $c->model(q[Visuals::Fastqcheck]);
  if (!$model->has_schema) {
    $model->schema($c->model(q[NpgQcDB]));
  }
  $self->_render($c, q[fastqcheck2image], $c->request->query_parameters);
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

=item English

=item Catalyst::Controller

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Genome Research Ltd.

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
