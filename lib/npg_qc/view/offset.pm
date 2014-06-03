#########
# Author:        gq1
# Created:       2009-01-20
#

package npg_qc::view::offset;
use strict;
use warnings;
use base qw(npg_qc::view);
use Carp;
use English qw(-no_match_vars);

our $VERSION = '0';

sub list {
  my ($self) = @_;
  my $cgi   = $self->util->cgi();
  my $model = $self->model();

  my $id_run = $cgi->param('id_run');
  my $lane = $cgi->param('lane');
  $model->id_run($id_run);
  $model->lane($lane);

  my $id_run_pair = $model->id_run_pair();
  if ($id_run_pair && $id_run_pair < $model->id_run()) {
    $model->id_run($id_run_pair);
  }

  return 1;
}

1;
__END__
=head1 NAME

npg_qc::view::offset

=head1 SYNOPSIS

  my $o = npg_qc::view::offset->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 list

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::view

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi, E<lt>gq1@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Andy Brown

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
