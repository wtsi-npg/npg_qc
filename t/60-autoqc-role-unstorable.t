use strict;
use warnings;
use Test::More tests => 7;
use File::Temp qw/tempdir/;

use_ok('npg_qc::autoqc::role::unstorable');
use_ok('npg_qc::autoqc::role::result');
use_ok('npg_qc::autoqc::results::result');
use_ok('npg_qc::autoqc::checks::check');

my $idrun = 2549;
my $pos = 2;
my $path = 't/data/autoqc/090721_IL29_2549/data';
my $tdir = tempdir( CLEANUP => 0 );

package npg_test::autoqc_result;
use Moose;
extends 'npg_qc::autoqc::results::result',;
with 'npg_qc::autoqc::role::unstorable',
     'npg_qc::autoqc::role::result',;
no Moose;

package npg_test::autoqc_check;
use Moose;
use npg_test::autoqc_result;
extends 'npg_qc::autoqc::checks::check';
has 'necessary_condition' => (is => 'ro', isa => 'Str', default => 'met',);
override 'execute' => sub {
    my ($self) = @_;
    $self->necessary_condition eq 'met' ? return 1 : $self->result->stop_storing;
    return 1;
};
no Moose;



package main;

subtest 'consume role' => sub {
    plan tests => 2;
    my $r = npg_test::autoqc_result->new(id_run => 12, position => 3, path => q[mypath]);
    isa_ok($r, 'npg_test::autoqc_result');
    can_ok($r, 'store_nomore');
};

subtest 'storable result' => sub {
    plan tests => 2;
    my $r = npg_qc::autoqc::results::result->new(id_run => 12, position => 3, path => q[mypath],);
    my $json_path = qq[$tdir/autoqc_check.json];
    $r->store($json_path);
    ok(-e $json_path, 'json file has been created');
    delete $r->{'store_nomore'};
    delete $r->{'filename_root'};
    my $saved_result = npg_qc::autoqc::results::result->load($json_path);
    sleep 1;
    unlink $json_path;
    is_deeply($r, $saved_result, 'serialization to JSON file');
};

subtest 'unstorable result' => sub {
    plan tests => 5;
    my $c = npg_test::autoqc_check->new(id_run => $idrun,
                                        position => $pos,
                                        qc_in => $path,
                                        qc_out => $tdir,
                                        filename_root => qq[$idrun\_$pos],
                                        file_type => q[fastqcheck],);
    isa_ok($c, 'npg_test::autoqc_check');
    is($c->can_run(), 1, 'check can run but should not be executed');
    ok($c->result(), 'create result object for check');
    ok($c->result->store_nomore(1), 'change flag in result object to stop storing');
    my $jpath = "$tdir/2549_2.autoqc_result.json";
    $c->run();
    ok(! -e $jpath, 'JSON file has not been created');
};

1;
