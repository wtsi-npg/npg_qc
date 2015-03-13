package npg_qc_viewer::Controller::Root;

use Moose;
use Readonly;
use Try::Tiny;
use Carp;

BEGIN { extends 'Catalyst::Controller' }

our $VERSION  = '0';
## no critic (Documentation::RequirePodAtEnd Subroutines::ProhibitBuiltinHomonyms)

=head1 NAME

npg_qc_viewer::Controller::Root - Root Controller for npg_qc_viewer

=head1 SYNOPSIS

=head1 DESCRIPTION

Catalyst Controller.

=head1 SUBROUTINES/METHODS

=cut

__PACKAGE__->config->{namespace} = q[];

Readonly::Scalar  our $NOT_FOUND_ERROR_CODE => 404;
Readonly::Scalar  our $UNAUTHORISED_CODE    => 401;
Readonly::Scalar  our $ADMIN_GROUP_NAME     => q[admin];

=head2 index

Index page action; redirection to the help page

=cut
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    $c->response->redirect($c->uri_for(q[checks]) );
    return;
}

=head2 default

Default action - page not found error page

=cut
sub default :Path {
    my ( $self, $c ) = @_;
    $c->stash->{error_message} = q[Page not found];
    $c->detach(q[error_page]);
    return;
}



=head2 error_page

Error page for problems with user input

=cut
sub error_page :Path :Args(1) {
    my ( $self, $c ) = @_;

    if (!$c->stash->{error_message}) {
        if ($c->error) {
            $c->stash->{error_message} = join q[:], @{$c->error};
            $c->clear_errors;
	}
    }
    if ( !$c->response->status || $c->response->status =~ /^2/smx ) {
        $c->response->status($NOT_FOUND_ERROR_CODE);
    }
    if ( $c->response->status == $NOT_FOUND_ERROR_CODE && !$c->stash->{error_message} ) {
        $c->stash->{error_message} = q[Page not found];
    }
    $c->stash->{template} = q[error_page.tt2];
    $c->stash->{title}    = q[NPG SeqQC error page];
    return;
}

=head2 auto

Runs at the start of each request (least specific auto)

=cut
sub auto :Private {
    my ( $self, $c ) = @_;
    #TODO consider using CatalystX::SimpleLogin

    #Whether the URL is valid or not, we are here.
    #Pre-compile a reg exp?

    if ( $c->req->path =~ /^autocrud\/site\/admin /smx) {
       try {
           $self->authorise($c, $ADMIN_GROUP_NAME);
       } catch {
           $self->detach2error($c, $UNAUTHORISED_CODE, $_);
       };
       $c->stash->{'template'} = q[about.tt2];
    }
    return 1; # essential to return 1, see Catalyst despatch schema
}

=head2 end

Attempt to render a view, if needed.

=cut 

sub end : ActionClass('RenderView') {}


=head2 authorise

User authorisation

=cut

sub authorise {
    my ($self, $c, @roles) = @_;
    my $user  = $c->req->params->{'user'};
    my $realm = $c->req->params->{'realm'};
    my $h = {};

    if (defined $user or defined $realm) {
        my $password     = $c->req->params->{password};
        $password = $password ? $password : q[];
        $user     = $user ? $user : q[];
        $c->logout;
        if (defined $user) {
            $h = { username => $user, password => $password };
        }
    }
    my $auth_ok;
    try {
        $auth_ok = $c->authenticate( $h, $realm);
    } catch {
        # non-existing realm gives an error
        croak qq[Login failed: $_];
    };

    if ( !$auth_ok ) {
        croak q[Login failed];
    }
    $c->log->debug('succeeded to authenticate');

    if (!$c->user_exists()) {
        croak q[User is not logged in];
    }

    if (@roles) {
        my $all_roles = join q[,], @roles;
        $c->log->debug(qq[asked to authorised against $all_roles]);
        my $logged_user = $c->user->id;
        if ( !$c->check_user_roles(@roles) ) {
            croak qq[User $logged_user is not a member of $all_roles];
        }
    }

    return;
}

=head2 detach2error

Displays error page with a relevant message and sets response status

=cut

sub detach2error {
    my ($self, $c, $code, $message) = @_;
    $c->log->debug($message);
    $c->error($message);
    $c->response->status($code);
    $c->detach(q[Root], q[error_page]);
    return;
}


1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Readonly

=item Carp

=item Try::Tiny

=item Moose

=item Catalyst::Controller

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown E<lt>ajb@sanger.ac.ukE<gt> and Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

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

