package npg_qc_viewer::Controller::Auth;

use Moose;
use namespace::autoclean;

use Catalyst::Authentication::Credential::SangerOIDC;

BEGIN { extends 'Catalyst::Controller' }

our $VERSION = '0';

sub _get_raw_param {
    my ( $self, $c, $param_name ) = @_;

    my $query_string = $c->req->env->{QUERY_STRING} // q{};

    my %raw_params;
    for my $pair ( split q{&}, $query_string ) { ## no critic (BuiltinFunctions::ProhibitStringySplit)
        my ( $key, $val ) = split /=/xsm, $pair, 2;
        $raw_params{$key} = URI::Escape::uri_unescape($val // q{});
    }

    return $raw_params{$param_name};
}

sub _clear_oidc_cookies {
    my ( $self, $c ) = @_;

    my %cookies;
    foreach my $pair ( split /;\s*/xsm, $c->req->env->{HTTP_COOKIE} // q{} ) {
        my ( $name, $value ) = split /=/xsm, $pair, 2;
        if (defined $name) {
            $cookies{$name} = $value;
        }
    }

    foreach my $cookie_name ( keys %cookies ) {
        if ( $cookie_name =~ /^npg_oidc_session_/xsmi ) {
            $c->res->cookies->{$cookie_name} = {
                value    => q{},
                expires  => '-1d',
                path     => q{/},
                secure   => 1,
                httponly => 1,
                domain   => '.sanger.ac.uk',
            };
        }
    }
    return 1;
}

sub login : Path('/auth/login') : Args(0) {
    my ( $self, $c ) = @_;

    my $user = Catalyst::Authentication::Credential::SangerOIDC->new(
         env => $c->req->env
    );
    my $username = $user->username;

    if ($username) {
        my $redirect_to = $self->_get_raw_param($c, 'redirect_to') || '/checks';
        $c->response->redirect($redirect_to);
        return 1;
    } else {
        $c->response->status('401');
        $c->response->body('Authentication failed: no username received.');
        return 0;
    }
}

sub logout : Path('/auth/logout') : Args(0) {
    my ( $self, $c ) = @_;

    my $redirect_to = $self->_get_raw_param($c, 'redirect_to') || '/checks';
    $c->session->{post_logout_redirect} = $redirect_to;

    my $post_logout_url = 'https://'
                          . $c->req->uri->authority
                          . '/auth/post-logout';

    $c->response->redirect('/callback?logout='
                           . URI::Escape::uri_escape($post_logout_url));
    return 1;
}

sub post_logout : Path('/auth/post-logout') : Args(0) {
    my ( $self, $c ) = @_;

    my $redirect_to = $c->session->{post_logout_redirect} || '/checks';

    $self->_clear_oidc_cookies($c);
    $c->delete_session('User logged out');

    $c->response->redirect($redirect_to);
    return 1;
}

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

npg_qc_viewer::Controller::Auth - Catalyst controller for OIDC authentication

=head1 SYNOPSIS

=head1 DESCRIPTION

NPG SeqQC Controller for Auth and post Auth actions. Handles login, logout,
and post-logout flow for OpenID Connect authentication via mod_auth_openidc.
Provides actions for the login callback, initiating logout, and cleaning up
after the OIDC session has been terminated.

=head1 SUBROUTINES/METHODS

=head2 login

    GET /auth/login

Handles the OIDC login callback. Reads the authenticated username from the
C<X-OIDC-Preferred-User> request header set by mod_auth_openidc. On success,
redirects to the C<redirect_to> parameter or C</checks> by default. Returns
a 401 response if no username is present in the header.

=head2 logout

    GET /auth/logout

Initiates the logout flow. Stores the post-logout destination (from the
C<redirect_to> parameter, defaulting to C</checks>) in the session, then
redirects to the OIDC provider logout endpoint. The provider will redirect
back to C</auth/post-logout> once the OIDC session is cleared.

=head2 post_logout

    GET /auth/post-logout

Completes the logout flow after the OIDC provider has terminated the session.
Clears any residual OIDC session cookies (C<npg_oidc_session_*>), deletes the
Catalyst session, and redirects the user to the originally requested
post-logout destination.

=head1 PRIVATE METHODS

=head2 _get_raw_param

    my $val = $self->_get_raw_param($c, 'redirect_to');

Reads a query parameter directly from C<QUERY_STRING> in the PSGI environment,
bypassing Catalyst's parameter parsing. This preserves the raw unmodified value
of the parameter, including any embedded URLs, which would otherwise be mangled
by Catalyst's decoding layer.

=head2 _clear_oidc_cookies

    $self->_clear_oidc_cookies($c);

Iterates over all cookies in the request and expires any whose name matches
C<npg_oidc_session_*>.

=cut

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Catalyst::Controller

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Avnish Pratap Singh E<lt>as74@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014,2015,2016,2017,2018,2019,2025,2026 Genome Research Ltd.

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
