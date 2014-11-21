use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;
use Test::MockObject;

use_ok 'Catalyst::Authentication::Credential::SangerSSOnpg';
isa_ok(Catalyst::Authentication::Credential::SangerSSOnpg->new(), 'Catalyst::Authentication::Credential::SangerSSOnpg');

my $mockcontext = Test::MockObject->new();
$mockcontext->mock('request',sub{my $to = Test::MockObject->new(); $to->set_always('uri','http://superserver/supper'); $to->set_always('cookie', undef)});
my $mocklog = Test::MockObject->new();
$mockcontext->mock('log',sub{$mocklog});
my $debug_msg;
$mocklog->mock('debug', sub {shift; $debug_msg = shift;});

my $mockrealm = Test::MockObject->new();
$mockrealm->mock('find_user',sub{shift; my$h=shift; return {%$h}if $h->{username}eq'dj3';return});

my $result;
lives_ok {$result = Catalyst::Authentication::Credential::SangerSSOnpg->authenticate($mockcontext, $mockrealm);} 'call authenticate';
cmp_ok($debug_msg,'eq','Cookie not found','Debug - no cookie');
is($result, undef, 'undef result if username is undefined');

1;



  

