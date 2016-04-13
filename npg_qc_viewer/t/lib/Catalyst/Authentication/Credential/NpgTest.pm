package Catalyst::Authentication::Credential::NpgTest;

use strict;
use warnings;

sub new {
    my ($class, $config, $app, $realm) = @_;
    my $self = { _config => $config };
    bless $self, $class;
    return $self;
}

sub authenticate {
    my ( $self, $c, $realm) = @_;
    my $username = $c->req->param('user');
    my $password;
    my $password_field  = $self->{'_config'}->{'password_field'} || 'password';
    my $global_password = $self->{'_config'}->{'global_password'} || 'none';

    if (!$username && (
          $c->request->content_type eq 'application/json' &&
          $c->request->method eq 'POST')) {
        my $body = $c->request->data;
        $username = $body->{'user'};
        $password = $body->{$password_field};
    } else {
        $password = $c->req->param($password_field);
    }
    if ($username && $password && $password eq $global_password) {
        return $realm->find_user({username=>$username}, $c);
    }
    return;
}

1;

