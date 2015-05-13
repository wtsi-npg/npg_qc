use strict;
use warnings;
use Test::More tests => 9;

use_ok('npg_tracking::daemon::seqqc');
{
    my $r = npg_tracking::daemon::seqqc->new();
    isa_ok($r, 'npg_tracking::daemon::seqqc');
    is(join(q[ ], @{$r->hosts}), q[sf2-farm-srv1 sf2-farm-srv2], 'list of hosts');
    is($r->command, q[npg_qc_viewer_server.pl -f -p 1959], 'script to run');
    is($r->daemon_name, 'seqqc', 'default daemon name');
    is($r->ping, q[daemon --running -n seqqc && ((if [ -w /tmp/seqqc.pid ]; then touch -mc /tmp/seqqc.pid; fi) && echo -n 'ok') || echo -n 'not ok'], 'ping command');
    is($r->stop, q[daemon --stop -n seqqc], 'stop command');
    like($r->start('myhost'), qr/npg_qc_viewer_server.pl -f -p/, 'the command contains the name of the catalyst start-up script');
    is_deeply($r->env_vars, {}, 'catalyst home is not set');
}

1;
