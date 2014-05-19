#########
# Author:        mg8
# Created:       1 September 2009
#

use strict;
use warnings;
use Test::More tests => 20;
use Test::Deep;
use Test::Exception;
use English qw(-no_match_vars);
use Carp;

use_ok ('npg_qc::autoqc::results::qX_yield');

{
    my $r = npg_qc::autoqc::results::qX_yield->new(id_run => 2, path => q[mypath], position => 1);
    isa_ok ($r, 'npg_qc::autoqc::results::qX_yield');
}


{
    my $r = npg_qc::autoqc::results::qX_yield->new(
                                                position  => 1,
                                                path      => 't/data/autoqc/090721_IL29_2549/data',
                                                id_run    => 2549
                                                  );
    is($r->check_name(), 'qX yield', 'check name');
    is($r->class_name(), 'qX_yield', 'class name');
    is($r->to_string, 'npg_qc::autoqc::results::qX_yield object for id_run 2549 position 1', 'description');
    is($r->threshold_quality, 20, 'default threshold quality');
}


{
    my $r = npg_qc::autoqc::results::qX_yield->new(
                                                position  => 1,
                                                path      => 't/data/autoqc/090721_IL29_2549/data',
                                                id_run    => 2549
                                                  );
    $r->threshold_yield1(21);
    $r->threshold_yield2(230);
    $r->yield1(200);
    $r->yield2(30);
    $r->filename1(q[f1]);
    $r->filename2(q[f2]);

    throws_ok {$r->pass_per_read(3)} qr/Invalid read index 3/, 'error on passing invalid index';
    is($r->pass_per_read(1), 1, 'pass value for read 1');
    is($r->pass_per_read(2), 0, 'pass value for read 2');
}


{
    my $r = npg_qc::autoqc::results::qX_yield->new(
                                                position  => 1,
                                                path      => 't/data/autoqc/090721_IL29_2549/data',
                                                id_run    => 2549
                                                  );
    $r->yield1(200);
    $r->filename1(q[f1]);
    is($r->pass_per_read(1), undef, 'no pass value if threshold undefined');
}


{
    my $r = npg_qc::autoqc::results::qX_yield->new(
                                                position  => 1,
                                                path      => 't/data/autoqc/090721_IL29_2549/data',
                                                id_run    => 2549
                                                  );
    $r->threshold_yield1(200);
    $r->filename1(q[f1]);
    is($r->pass_per_read(1), undef, 'no pass value if yield undefined');
}


{
    my $r = npg_qc::autoqc::results::qX_yield->new(
                                                position  => 1,
                                                path      => 't/data/autoqc/090721_IL29_2549/data',
                                                id_run    => 2549
                                                  );
    is($r->criterion, 'yield (number of KBs at and above Q20) is greater than the threshold', 'criterion string');
}

{
    my $json = 't/data/autoqc/4453_2#0.qX_yield.json';
    my $r;
    lives_ok {$r = npg_qc::autoqc::results::qX_yield->load($json)} 'loaded json for no-file error';
    is($r->pass, undef, 'pass is undef');
    is($r->yield1, undef, 'yield1 is undef');
    is($r->yield2, undef, 'yield2 is undef');
    is($r->threshold_yield1, undef, 'threshold1 is undef');
    is($r->threshold_yield2, undef, 'threshold2 is undef');
    is($r->threshold_quality, 20, 'threshold quality ok');
    is($r->to_string, 'npg_qc::autoqc::results::qX_yield object for id_run 4453 position 2 tag index 0', 'description');
}
