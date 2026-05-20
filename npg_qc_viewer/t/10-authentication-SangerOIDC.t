use strict;
use warnings;

use Test::More;

use_ok('Catalyst::Authentication::Credential::SangerOIDC');

# -----------------------
# Constructor
# -----------------------

{
  my $oidc = Catalyst::Authentication::Credential::SangerOIDC->new(
    env => { HTTP_X_OIDC_name => 'Tiger Cat' },
  );
  isa_ok($oidc, 'Catalyst::Authentication::Credential::SangerOIDC', 'object created with env');
}

{
  my $oidc = Catalyst::Authentication::Credential::SangerOIDC->new();
  isa_ok($oidc, 'Catalyst::Authentication::Credential::SangerOIDC', 'object created without env arg');
}

# -----------------------
# name
# -----------------------

{
  my $oidc = Catalyst::Authentication::Credential::SangerOIDC->new(
    env => { HTTP_X_OIDC_name => 'Tiger Cat' },
  );
  is($oidc->name, 'Tiger Cat', 'name returns full display name');
}

{
  my $oidc = Catalyst::Authentication::Credential::SangerOIDC->new(env => {});
  ok(!defined $oidc->name, 'name returns undef when header absent');
}

{
  my $oidc = Catalyst::Authentication::Credential::SangerOIDC->new(env => 'not-a-hash');
  ok(!defined $oidc->name, 'name returns undef for non-hash env');
}

# -----------------------
# username: plain (no @ in value)
# -----------------------

{
  my $oidc = Catalyst::Authentication::Credential::SangerOIDC->new(
    env => { HTTP_X_OIDC_PREFERRED_USER => 'tiger' },
  );
  is($oidc->username, 'tiger', 'username returned unchanged when no @ present');
}

# -----------------------
# username: value contains email domain
# -----------------------

{
  my $oidc = Catalyst::Authentication::Credential::SangerOIDC->new(
    env => { HTTP_X_OIDC_PREFERRED_USER => 'tiger@sanger.ac.uk' },
  );
  is($oidc->username, 'tiger', 'username strips email domain after @');
}

# -----------------------
# username: malformed — starts with @
# -----------------------

{
  my $oidc = Catalyst::Authentication::Credential::SangerOIDC->new(
    env => { HTTP_X_OIDC_PREFERRED_USER => '@sanger.ac.uk' },
  );
  is($oidc->username, q{}, 'username is empty string when value starts with @');
}

# -----------------------
# username: multiple @ signs
# -----------------------

{
  my $oidc = Catalyst::Authentication::Credential::SangerOIDC->new(
    env => { HTTP_X_OIDC_PREFERRED_USER => 'tiger@foo@bar' },
  );
  is($oidc->username, 'tiger', 'username returns part before first @ when multiple @ present');
}

# -----------------------
# username: missing header
# -----------------------

{
  my $oidc = Catalyst::Authentication::Credential::SangerOIDC->new(env => {});
  ok(!defined $oidc->username, 'username returns undef when header absent');
}

# -----------------------
# username: empty string value
# -----------------------

{
  my $oidc = Catalyst::Authentication::Credential::SangerOIDC->new(
    env => { HTTP_X_OIDC_PREFERRED_USER => q{} },
  );
  ok(!defined $oidc->username, 'username returns undef for empty header value');
}

# -----------------------
# username: non-hash env
# -----------------------

{
  my $oidc = Catalyst::Authentication::Credential::SangerOIDC->new(env => 'not-a-hash');
  ok(!defined $oidc->username, 'username returns undef for non-hash env');
}

# -----------------------
# username: default empty env (no arg)
# -----------------------

{
  my $oidc = Catalyst::Authentication::Credential::SangerOIDC->new();
  ok(!defined $oidc->username, 'username returns undef when constructed without env');
}

done_testing();
