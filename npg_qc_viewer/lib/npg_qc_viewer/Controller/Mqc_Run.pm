package npg_qc_viewer::Controller::Mqc_Run;

use Moose;
use namespace::autoclean;
use Readonly;
use Try::Tiny;
use Carp;

BEGIN { extends 'Catalyst::Controller::REST' }

#Just to declare a default. But seems the content type should come from client
#anyway
__PACKAGE__->config( default => 'application/json' );

with 'npg_qc_viewer::api::error';
with 'npg_qc_viewer::Util::Rest_controller';

our $VERSION = '0';

Readonly::Scalar my $MQC_ROLE            => q[manual_qc];
Readonly::Scalar my $OK_CODE             => 200;

## no critic (NamingConventions::Capitalization)
sub mqc_runs : Path('/mqc/mqc_runs') : ActionClass('REST') { }

sub mqc_runs_GET {
  my ( $self, $c, $id_run ) = @_;
  my $username;
  my $error;

  try {
    ####Authorisation
    $c->controller('Root')->authorise( $c, ($MQC_ROLE) );

    #Get from DB
    my $ent = $c->model('NpgDB')->resultset('Run')->find($id_run);
    use Data::Dumper;
    print($ent->dump(4));

    # Return a 200 OK, with the data in entity
    # serialized in the body
    $self->status_ok(
      $c,
      entity => {
        id_run                     => $id_run,
        current_status_description => $ent->current_run_status_description,
      },
    );
  } catch {
    $error = $_;
  };
  
  my $error_code = $OK_CODE;

  if ($error) {
    print (qq[Found error $error]);
    ( $error, $error_code ) = $self->parse_error($error);
    if ($error_code == 401) {
        $self->status_unauthorized(
          $c,
          message => $error,
        );
    } elsif (1) {
      print("Fu");
    } 
  }
  
  return;
}

#__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

npg_qc_viewer::Controller::Mqc_Run

=head1 SYNOPSIS

=head1 DESCRIPTION

Controller to expose runs through REST

=head2 mqc_runs

  Placeholder for the REST path for runs.

=head2 mqc_runs_GET

  Returns general information about the status of the run specified as part of the URL.

=head1 SUBROUTINES/METHODS 

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Readonly

=item namespace::autoclean

=item Moose

=item Catalyst::Controller::REST

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Jaime Tovar E<lt>jmtc@sanger.ac.ukE<gt>

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
