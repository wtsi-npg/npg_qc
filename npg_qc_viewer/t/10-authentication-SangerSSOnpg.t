use strict;
use warnings;

use Test::More;
use Test::MockObject;

use Catalyst::Authentication::Credential::SangerSSOnpg;

sub build_context {
    my (%args) = @_;

    my $env = $args{env} || {};

    my $request = Test::MockObject->new;
    $request->mock('uri', sub { return '/test-uri' });

    my $req = Test::MockObject->new;
    $req->mock('env', sub { return $env });

    my $log = Test::MockObject->new;
    $log->mock('debug', sub { return 1 });

    my $c = Test::MockObject->new;
    $c->mock('request', sub { return $request });
    $c->mock('req',     sub { return $req });
    $c->mock('log',     sub { return $log });

    return $c;
}

sub build_realm {
    my $realm = Test::MockObject->new;

    $realm->mock('find_user', sub {
        my ($self, $args, $c) = @_;
        return { username => $args->{username} };
    });

    return $realm;
}

# -----------------------
# Test: username with @
# -----------------------

{
    my $env = {
        HTTP_X_OIDC_PREFERRED_USER => 'tiger@example.com',
    };

    my $c     = build_context(env => $env);
    my $realm = build_realm();

    my $sso = Catalyst::Authentication::Credential::SangerSSOnpg->new({}, undef, undef);

    my $user = $sso->authenticate($c, $realm);

    is($user->{username}, 'tiger', 'extracts username before @');
}

# -----------------------
# Test: username without @
# -----------------------

{
    my $env = {
        HTTP_X_OIDC_PREFERRED_USER => 'tiger',
    };

    my $c     = build_context(env => $env);
    my $realm = build_realm();

    my $sso = Catalyst::Authentication::Credential::SangerSSOnpg->new({}, undef, undef);

    my $user = $sso->authenticate($c, $realm);

    is($user->{username}, 'tiger', 'uses full username when no @ present');
}

# -----------------------
# Test: missing username
# -----------------------

{
    my $env = {};

    my $c     = build_context(env => $env);
    my $realm = build_realm();

    my $sso = Catalyst::Authentication::Credential::SangerSSOnpg->new({}, undef, undef);

    my $user = $sso->authenticate($c, $realm);

    ok(!defined $user, 'returns undef when username missing');
}

# -----------------------
# Test: empty username
# -----------------------

{
    my $env = {
        HTTP_X_OIDC_PREFERRED_USER => '',
    };

    my $c     = build_context(env => $env);
    my $realm = build_realm();

    my $sso = Catalyst::Authentication::Credential::SangerSSOnpg->new({}, undef, undef);

    my $user = $sso->authenticate($c, $realm);

    ok(!defined $user, 'returns undef when username is empty');
}

# -----------------------
# Test: ensure find_user is called correctly
# -----------------------

{
    my $called = 0;

    my $realm = Test::MockObject->new;
    $realm->mock('find_user', sub {
        my ($self, $args, $c) = @_;
        $called = 1;
        is($args->{username}, 'cat', 'find_user called with correct username');
        return { username => 'cat' };
    });

    my $env = {
        HTTP_X_OIDC_PREFERRED_USER => 'cat@example.com',
    };

    my $c = build_context(env => $env);

    my $sso = Catalyst::Authentication::Credential::SangerSSOnpg->new({}, undef, undef);

    my $user = $sso->authenticate($c, $realm);

    ok($called, 'find_user was called');
    is($user->{username}, 'cat', 'correct user returned');
}

done_testing();
