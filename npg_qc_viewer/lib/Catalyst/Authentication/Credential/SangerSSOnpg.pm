package Catalyst::Authentication::Credential::SangerSSOnpg;

use strict;
use warnings;
use npg::authentication::sanger_sso qw/sanger_cookie_name sanger_username/;

our $VERSION = '0';

sub new {
    my ($class, $config, $app, $realm) = @_;
    my $self = { _config => $config };
    bless $self, $class;
    return $self;
}

sub authenticate {
    my ( $self, $c, $realm) = @_;
    $c->log->debug('SangerSSOnpg authenticate() called from ' . $c->request->uri) ;

    my $cookie = $c->request->cookie(sanger_cookie_name());
    if(!$cookie) {
        $c->log->debug('Cookie not found');
        return;
    }
    $c->log->debug('Found cookie ' . $cookie->name . ' = ' . $cookie->value);
    my $key = $self->{_config}->{decryption_key};
    if (!$key) {
        $c->log->debug('Decription key not found');
        return;
    }
    $c->log->debug('Got decryption key ' . $key);
    my $username = sanger_username($cookie->value, $key);
    if ($username) {
        return $realm->find_user({username=>$username}, $c);
    }
    $c->log->debug(q[Can't extract username]);
    return;
}

1;
__END__

=head1 NAME

  Catalyst::Authentication::Credential::SangerSSOnpg

=head1 SYNOPSIS

    #action in a controller
    sub login : Local {
        my ( $self, $c ) = @_;
        my $user     = $c->req->params->{user};
        my $realm = $c->req->params->{realm};
        if (defined $user or defined $realm) {
            my $password     = $c->req->params->{password};
            $c->logout;
            if ( $c->authenticate( defined $user ? { username => $user, password => $password } :{} , $realm) ) {
                # login correct
            } else {
                # login incorrect
            }
        }
    }

 #config
 <Plugin::Authentication>
  default_realm = dbic_realm
  <realms>
  <test_realm>
    <credential>
          class = Password
          password_field = password
          password_type = clear
    </credential>
    <store>
          class = Minimal
          <users>
             <bob>
                  password = s00p3r
                  editor = yes
                  roles = edit
                  roles = delete
             </bob>
             <dj3>
                  password = s3cr3t
                  roles = comment
                  roles = foofoo
             </dj3>
          </users>
    </store>
  </test_realm>
  <ssso_mini_realm>
    <credential>
                  class           = SangerSSO
    </credential>
    <store>
          class = Minimal
          <users>
             <dj3>
                  roles = admin
                  roles = superfoo
             </dj3>
          </users>
    </store>
  </ssso_mini_realm>
  <mini_realm>
    <credential>
                  class           = Testing
                  password_field  = password
                  global_password = secret
    </credential>
    <store>
          class = Minimal
          <users>
             <dj3>
                  roles = admin
                  roles = rant
             </dj3>
          </users>
    </store>
  </mini_realm>
  <dbic_realm>
    <credential>
                  class           = Testing
                  password_field  = password
                  global_password = secret
    </credential>
    <store>
          class = DBIx::Class
          user_model = tracking::User
          role_relation = usergroups
          role_field = groupname
          use_userdata_from_session = 1
    </store>
  </dbic_realm>
  <ssso_realm>
    <credential>
          class           = SangerSSO
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

Catalyst Credential module to allow authentication using the Sanger's web single sign on system.

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

=item Readonly

=item npg::authentication::sanger_sso

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David Jackson

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Genome Research Limited

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
