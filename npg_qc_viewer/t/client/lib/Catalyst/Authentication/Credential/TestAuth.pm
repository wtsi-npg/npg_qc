package Catalyst::Authentication::Credential::TestAuth;

use strict;
use warnings;

our $VERSION = '0';

sub new {
  my ($class, $config, $app, $realm) = @_;
  my $self = { _config => $config };
  bless $self, $class;
  return $self;
}

sub authenticate {
  my ( $self, $c, $realm) = @_;
  $c->log->debug('TestAuth authenticate() called from ' . $c->request->uri) ;

  my $cookie_name = $self->{_config}->{cookie_name};
  my $cookie = $c->request->cookie($cookie_name);
  if(!$cookie) {
    $c->log->debug('Cookie not found');
    return;
  }
  $c->log->debug('Found cookie ' . $cookie->name . ' = ' . $cookie->value);
  my $username = $cookie->value;
  if ($username) {
    return $realm->find_user({username=>$username}, $c);
  }
  $c->log->debug(q[Can't extract username]);
  return;
}

1;
__END__

=head1 NAME

  Catalyst::Authentication::Credential::TestAuth

=head1 SYNOPSIS

 #config
 <Plugin::Authentication>
  default_realm = ssso_realm
  <realms>
  <ssso_realm>
    <credential>
          class = TestAuth
    </credential>
    <store>
          class = DBIx::Class
          user_model = tracking::User
          role_relation = usergroups
          role_field = groupname
          use_userdata_from_session = 1
    </store>
  </ssso_realm>
  </realms>
 </Plugin::Authentication>


=head1 DESCRIPTION

Catalyst Credential module to allow user authentication through a clear text cookie in the client during tests.

=head1 SUBROUTINES/METHODS

=head2 new - creates an object

=head2 authenticate

Called by Catalyst authentication infrastructure....

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

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
