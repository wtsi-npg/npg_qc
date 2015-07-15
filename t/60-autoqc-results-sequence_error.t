use strict;
use warnings;
use Test::More tests => 19;
use Test::Exception;

use_ok ('npg_qc::autoqc::results::sequence_error');

{
    my $r = npg_qc::autoqc::results::sequence_error->new(id_run => 2, path => q[mypath], position => 1);
    isa_ok ($r, 'npg_qc::autoqc::results::sequence_error');
    is ($r->filename4serialization(), '2_1.sequence_error.json', 'default file name');
    is ($r->check_name, q[sequence mismatch], 'check name changed to sequence mismatch');
    $r = npg_qc::autoqc::results::sequence_error->new(
      id_run => 2, path => q[mypath], position => 1, sequence_type => 'spiked_phix');
    is ($r->sequence_type, q[spiked_phix], 'spiked phix sequence type');
    is ($r->check_name, q[sequence mismatch spiked phix], 'check name for spiked phix type');
    is ($r->filename4serialization(), '2_1_spiked_phix.sequence_error.json',
      'file name contains "spiked_phix" flag');
}

{
    my $r;
    my $ape;

    lives_ok {
      $r = npg_qc::autoqc::results::sequence_error->load('t/data/autoqc/4078_1.sequence_error.json');
    } q(load serialised empty result);
    isa_ok ($r, 'npg_qc::autoqc::results::sequence_error');
    lives_ok { $ape = $r->reverse_average_percent_error; } q(reverse_average_percent_error run);
    cmp_ok($ape, q(eq), q(nan), q(reverse_average_percent_error value));

    lives_ok {
      $r = npg_qc::autoqc::results::sequence_error->load('t/data/autoqc/4068_3.sequence_error.json');
    } q(load serialised valid result);
    lives_ok { $ape = $r->reverse_average_percent_error; } q(reverse_average_percent_error run);
    cmp_ok($ape, q(==), 1.58, q(reverse_average_percent_error value));
    my $rft = $r->reference_for_title;
    cmp_ok($rft->{'species'}, q[==], q[Homo_sapiens]);
    cmp_ok($rft->{'version'}, q[==], q[NCBI36]);

    lives_ok {
      $r = npg_qc::autoqc::results::sequence_error->load('t/data/autoqc/9999_1.sequence_error.json');
    } q(load serialised valid result);
    lives_ok { $ape = $r->reverse_average_percent_error; } q(reverse_average_percent_error run);
    cmp_ok($ape, q(==), 1.58, q(reverse_average_percent_error value));
}

1;

