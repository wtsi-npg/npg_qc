use strict;
use warnings;
use Test::More tests => 21;
use Test::Exception;

use_ok ('npg_qc::autoqc::results::insert_size');

{
    my $r = npg_qc::autoqc::results::insert_size->new(id_run => 12, position => 3, path => q[mypath]);
    isa_ok ($r, 'npg_qc::autoqc::results::insert_size');
    is($r->check_name(), 'insert size', 'check name');
    is($r->class_name(), 'insert_size', 'class name');
    is($r->criterion(), q[The value of the third quartile is larger than the lower boundary of the expected size], 'criteria');
}

{
    my $r = npg_qc::autoqc::results::insert_size->new(id_run => 12, position => 3, path => q[mypath]);
    my $comment1 = q[my comment];
    $r->add_comment($comment1);
    is($r->comments, $comment1, 'one comment added');
    my $comment2 = q[your comment];
    $r->add_comment($comment2);
    is($r->comments, $comment1 . q[ ] . $comment2, 'two comments added');
}

{
    my $r = npg_qc::autoqc::results::insert_size->new(id_run => 12, position => 3, path => q[mypath]);

    my $ref_path = q[/references/Human/default/all/bwa/Homo_sapiens.NCBI36.48.dna.all.fa];
    $r->expected_mean(350);
    $r->filenames(['f1', 'f2']);
    $r->sample_size(10000);
    $r->reference($ref_path);

    is($r->reference, $ref_path, 'reference path returned');
    is($r->sample_size, 10000, 'sample size returned');
    is($r->expected_size_range(), '350', 'expected range returned');
    is(join(q[ ], @{$r->filenames}), 'f1 f2', 'filenames returned');
}

{
    my $r = npg_qc::autoqc::results::insert_size->load(q[t/data/autoqc/insert_size/6062_8#1.insert_size.json]);
    $r->paired_reads_direction_in(0);
    ok(!$r->num_well_aligned_reads_opp_dir, 'number reads aligned in opposite direction not defined');
}

{
    my $expected_mean_file = q[t/data/autoqc/insert_size_expected_mean.json];
    my $r;
    lives_ok {$r = npg_qc::autoqc::results::insert_size->load($expected_mean_file);}
      'loading from a json string with expected_mean defined should not die';

    is($r->expected_mean, 500, 'attr value for expected_mean');
    is($r->expected_size, undef, 'expected_size attr is not defined');
    is($r->expected_size_range(), 500, 'display value for expected mean');
}

{
    my $expected_size_file = q[t/data/autoqc/insert_size_expected_size.json];

    my $r = undef;
    lives_ok {$r = npg_qc::autoqc::results::insert_size->load($expected_size_file);} 'loading from a json string with expected_size defined should not die';
    is(join(q[ ], @{$r->expected_size}), '400 500', 'attr value for expected_size');
    is($r->expected_mean, undef, 'expected_mean attr is not defined');
    is($r->expected_size_range(), '400:500', 'display value for expected size');
}

{
    my $r = npg_qc::autoqc::results::insert_size->new(id_run => 12, 
                                                      position => 3, 
                                                      path => q[mypath],
                                                      expected_size => [34, 56, 78, 23, 83, 56, 12, 35, 22],
                                                     );
    is($r->expected_size_range(), '12:83', 'display value for expected size in case of multiple expect sizes');
}

1;

