package Catalyst::Authentication::Credential::SangerOIDC;

use strict;
use warnings;

our $VERSION = '0';

sub new {
  my ($class, %args) = @_;

  my $self = {
    env => $args{env} || {},
  };

  bless $self, $class;
  return $self;
}

sub _h {
  my ($self, $key) = @_;
  return if ref $self->{env} ne 'HASH';
  return $self->{env}{$key};
}

sub name {
  my $self = shift;
  return $self->_h('HTTP_X_OIDC_name');
}

sub username {
  my $self = shift;
  my $preferred_username = $self->_h('HTTP_X_OIDC_PREFERRED_USER') // q{};

  if ($preferred_username) {
    return (split /@/smx, $preferred_username)[0];
  }
  return;
}
1;
__END__

=pod

=head1 NAME

Catalyst::Authentication::Credential::SangerOIDC - Simple OIDC claim helper

=head1 SYNOPSIS

  use Catalyst::Authentication::Credential::SangerOIDC;

  my $oidc = Catalyst::Authentication::Credential::SangerOIDC->new(
    env => $c->req->env,
  );

  my $name = $oidc->name;
  my $username = $oidc->username;

=head1 DESCRIPTION

This module provides a lightweight interface for accessing OpenID Connect
(OIDC) identity information passed from an upstream reverse proxy
(such as Apache with mod_auth_openidc).

It expects OIDC claims to be exposed as HTTP headers in the PSGI environment,
typically prefixed with C<HTTP_X_OIDC_*>.

This module does not perform authentication itself. It only provides a clean
object-oriented interface to identity data already validated by upstream systems.

=head1 SUBROUTINES/METHODS

=head1 CONSTRUCTOR

=head2 new

  my $oidc = Catalyst::Authentication::Credential::SangerOIDC->new(%args);

Creates a new instance and loads OIDC claims and tokens from the
environment.

=over 4

=item * env => HASHREF (required)

PSGI environment hash containing HTTP headers.

=back

=head1 METHODS

=head2 name

Returns the user's full display name.

=head2 username

Returns the preferred username from the identity provider.

=head2 Additional attributes

Currently only few user attributes are fetched from OIDC. Additional,
attributes can be fetched as below:

Subject: Returns the OIDC subject (unique user identifier).

sub subject {
  my $self = shift;
  return $self->_h('HTTP_X_OIDC_sub');
}

Email: Returns the user's email address.

sub email {
  my $self = shift;
  return $self->_h('HTTP_X_OIDC_email');
}

Groups: Returns an array reference of groups the user belongs to.

Groups are expected to be provided as a comma-separated string
in the C<HTTP_X_OIDC_groups> header.

sub groups {
  my $self = shift;
  my $raw = $self->_h('HTTP_X_OIDC_groups') || q{};
  return [ grep { length } split /\s*,\s*/xsm, $raw ];
}

Access Token: Returns the OIDC access token.

sub access_token {
  my $self = shift;
  return $self->_h('HTTP_X_OIDC_access_token');
}

ID Token: Returns the OIDC ID token.

sub id_token {
  my $self = shift;
  return $self->_h('HTTP_X_OIDC_id_token');
}

has_group: Returns true if the user belongs to the specified group.

sub has_group {
  my ($self, $group) = @_;
  return grep { $_ eq $group } @{ $self->groups };
}

=head1 ENVIRONMENT

This module expects the following HTTP headers in the PSGI environment:

=over 4

=item * HTTP_X_OIDC_name

=item * HTTP_X_OIDC_PREFERRED_USER

=back

These are typically set by a reverse proxy such as Apache with
mod_auth_openidc.

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Relies entirely on upstream authentication (no token validation performed).

=item *

Assumes group data is comma-separated.

=item *

No normalization of claims is performed.

=back

=head1 INCOMPATIBILITIES

=head1 AUTHOR

Avnish Pratap Singh <as74@sanger.ac.uk>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2026 Genome Research Ltd

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
