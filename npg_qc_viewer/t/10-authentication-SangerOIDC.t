use strict;
use warnings;

use Test::More;

use_ok('Catalyst::Authentication::Credential::SangerOIDC');

# -----------------------
# Test data
# -----------------------

my $env = {
    HTTP_X_OIDC_sub              => 'user-123',
    HTTP_X_OIDC_email            => 'tiger@example.com',
    HTTP_X_OIDC_name             => 'Tiger Cat',
    HTTP_X_OIDC_PREFERRED_USER   => 'tiger',
    HTTP_X_OIDC_groups           => 'admin, users, dev',
    HTTP_X_OIDC_access_token     => 'access-token-abc',
    HTTP_X_OIDC_id_token         => 'id-token-xyz',
};

my $oidc = Catalyst::Authentication::Credential::SangerOIDC->new(env => $env);

# -----------------------
# Constructor
# -----------------------

isa_ok($oidc, 'Catalyst::Authentication::Credential::SangerOIDC');

# -----------------------
# Accessors
# -----------------------

is($oidc->subject, 'user-123', 'sub accessor works');
is($oidc->email, 'tiger@example.com', 'email accessor works');
is($oidc->name, 'Tiger Cat', 'name accessor works');
is($oidc->username, 'tiger', 'username accessor works');

is($oidc->access_token, 'access-token-abc', 'access token works');
is($oidc->id_token, 'id-token-xyz', 'id token works');

# -----------------------
# Groups parsing
# -----------------------

my $groups = $oidc->groups;

isa_ok($groups, 'ARRAY', 'groups returns arrayref');

is_deeply(
    $groups,
    ['admin', 'users', 'dev'],
    'groups split correctly with spaces'
);

# -----------------------
# has_group
# -----------------------

ok($oidc->has_group('admin'), 'has_group detects admin');
ok(!$oidc->has_group('missing'), 'has_group rejects unknown group');

# -----------------------
# Edge cases: missing env
# -----------------------

my $empty = Catalyst::Authentication::Credential::SangerOIDC->new(env => {});

ok(!defined $empty->subject, 'missing sub returns undef');
ok(!defined $empty->email, 'missing email returns undef');

is_deeply(
    $empty->groups,
    [],
    'empty groups returns empty arrayref'
);

ok(!$empty->has_group('admin'), 'has_group false when no groups');

# -----------------------
# Edge case: malformed env
# -----------------------

my $bad = Catalyst::Authentication::Credential::SangerOIDC->new(env => 'not-a-hash');

ok(!defined $bad->email, 'non-hash env handled safely');

# -----------------------
# Edge case: group formatting variations
# -----------------------

my $env_variation = {
    HTTP_X_OIDC_groups => 'admin,users,dev',
};

my $oidc_variation = Catalyst::Authentication::Credential::SangerOIDC->new(
    env => $env_variation
);

is_deeply(
    $oidc_variation->groups,
    ['admin', 'users', 'dev'],
    'groups split correctly without spaces'
);

done_testing();
