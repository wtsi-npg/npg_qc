#########
# Author:        jo3
# Maintainer:    $Author$
# Created:       Autumn 2010
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#
use strict;
use warnings;
use autodie qw(:all);
use File::Temp qw/ tempdir /;
use File::Spec::Functions qw(catfile);
use Cwd;

use Test::More tests => 44;
use Test::Deep;
use Test::Exception;

use_ok('npg_qc::autoqc::checks::ref_match');

my $fastq_path = 't/data/autoqc';
my $repos = join q[/], cwd, q[t/data/autoqc];
my $ref_repos  = getcwd() . '/t/data/autoqc/references';

my $dir = tempdir( CLEANUP => 1 );
my $bt = join q[/], $dir, q[bowtie];
open my $fh,  q[>], $bt;
print $fh qq[cat t/data/autoqc/alignment_refmatch.sam\n];
close $fh;
`chmod +x $bt`;

{
    my $test;
    local $ENV{PATH} = join ':', $dir, $ENV{PATH}; 

    lives_ok {
        $test = npg_qc::autoqc::checks::ref_match->new(
                        path     => $fastq_path,
                        id_run   => 1937,
                        position =>    3,
                        repository => $repos,
        );
    }
    'Create the minimal check object';

    isa_ok( $test, 'npg_qc::autoqc::checks::ref_match' );
    is( $test->aligner(), 'bowtie', 'default aligner is set' );
    is( $test->aligner_cmd(), $bt, 'abs path to the aligner');
    is( $test->aligner_options(), '--quiet --sam --sam-nohead %ref% %reads%', 'bowtie options returned' );
    ok( defined $test->ref_repository(),
        'A default reference repository is set' );
    my $temp_dir = $test->tmp_path();
    ok( -d $temp_dir, 'Temporary directory created' );
    ok( $test->temp_fastq() =~ m{^ $temp_dir / \S+ }msx,
        'Temporary fastq path is in the temp dir' );
    ok( $test->sample_read_length() =~ m/^ \d+ $/msx,
        'A default read length is set' );
    ok( $test->sample_read_count()  =~ m/^ \d+ $/msx,
        'A default read count is set' );
}

{
    my $override_test;

    lives_ok {
        $override_test = npg_qc::autoqc::checks::ref_match->new(
                        path               => $fastq_path,
                        id_run             => 1937,
                        position           =>    3,
                        repository         => $repos,
                        aligner            => 'smalt',
                        temp_fastq         => '/tEmp/faStq',
                        sample_read_length => 250,
                        sample_read_count  => 3,
                        request_list       => [ 'abc', 'def' ],
                        ref_repository     => 't/data',
        );
    }
    'Various things can be set if needed';

    isa_ok( $override_test, 'npg_qc::autoqc::checks::ref_match' );

    is( $override_test->aligner(), 'smalt',
        'Default aligner overridden' );
    is( $override_test->aligner_options(), 'map -f sam %ref% %reads%',
        'smalt aligner options' );
    is( $override_test->temp_fastq(), '/tEmp/faStq',
        'Default temporary fastq path overridden' );
    is( $override_test->sample_read_length(), 250,
        'Default read length overridden' );
    is( $override_test->sample_read_count(), 3,
        'Default read count overridden' );
    cmp_bag( $override_test->request_list(), [ 'abc', 'def' ],
        'Requested organism list explicitly specified' );
    is( $override_test->ref_repository(), 't/data',
        'Default reference repository overridden' );
}

{
    throws_ok {
        npg_qc::autoqc::checks::ref_match->new(
                        path               => $fastq_path,
                        id_run             => 1937,
                        position           =>    3,
                        sample_read_length =>   27,
                        sample_read_count  =>    3,
                        repository => $repos,
        )
    } qr/Sample read length 27 is below 28 \(lowest acceptable value\)/,
    'error when requesting too short reads';
}

{
    my $test = npg_qc::autoqc::checks::ref_match->new(
                        path               => $fastq_path,
                        id_run             => 1937,
                        position           =>    3,
                        sample_read_length =>   37,
                        sample_read_count  =>    3,
                        read1_fastq        => q[t/data/autoqc/ref_match/narrow.fastq],
                        repository => $repos,
    );
    lives_ok { $test->execute() }
             'No error when reads are shorter than requested';
    is($test->result->comments, q[Read length of 4 is below minimally required 28], 'comment for a v short read');
}


{
    my $test;
    lives_ok {
        $test = npg_qc::autoqc::checks::ref_match->new(
                        path               => $fastq_path,
                        id_run             => 1937,
                        position           =>    3,
                        sample_read_length =>   39,
                        sample_read_count  =>    3,
                        repository => $repos,
        );
    }
    'Set sample length to 38 for a 37 bp read length';

    lives_ok { $test->_create_sample_fastq() }
             'No error when reads are shorter than requested';
    ok( -e $test->temp_fastq(), 'Temp fastq file created' );
    is( $test->result->sample_read_length(), 37, 'Sample read length is 37' );
    is( $test->result->sample_read_count(),   3, 'Sample read count is 3' );
}


{
    my $test = npg_qc::autoqc::checks::ref_match->new(
                        path               => $fastq_path,
                        id_run             => 1937,
                        position           =>    2,
                        repository => $repos,
    );

    ok(!$test->_create_sample_fastq(), 'creating sample fastq for an empty file returns false');
    lives_ok {$test->execute()} 'execute method for an empty fastq file lives';
    like( $test->result->comments(), qr/[.]fastq[ ]is[ ]empty/msx,
          'Store an appropriate comment for an empty fastq file' );
}


{
    local $ENV{PATH} = join ':', $dir, $ENV{PATH}; 

    my $test = npg_qc::autoqc::checks::ref_match->new(
                path           => $fastq_path,
                id_run         => 1937,
                position       =>    3,
                ref_repository => $ref_repos,
                repository => $repos,
    );

    isa_ok( $test, 'npg_qc::autoqc::checks::ref_match', 'The test object for testing organism list building' );

    cmp_bag( $test->organism_list(), [ 'Homo_sapiens', 'Vibrio_cholerae' ],
             'Default organism list is correct' );

    is_deeply( $test->reference_version(),
               {
                'Homo_sapiens'    => 'NCBI36',
                'Vibrio_cholerae' => 'M66-2'
               },
               'Default reference version list is correct'
    );

    is_deeply( $test->index_base(),
               {
                'Homo_sapiens' => $ref_repos .
                            '/Homo_sapiens/NCBI36/all/bowtie/someref.fa',
                'Vibrio_cholerae' => $ref_repos .
                            '/Vibrio_cholerae/M66-2/all/bowtie/V_chol.fasta'
               },
               'Default index base list is correct'
    );


    $test = npg_qc::autoqc::checks::ref_match->new(
                path           => $fastq_path,
                id_run         => 1937,
                position       =>    3,
                ref_repository => $ref_repos,
                request_list   => ['Vibrio_cholerae'],
                repository => $repos,
    );

    cmp_bag( $test->organism_list(), ['Vibrio_cholerae'],
             'Request list argument effective' );
}


{
    local $ENV{PATH} = join ':', $dir, $ENV{PATH}; 

    my $test = npg_qc::autoqc::checks::ref_match->new(
                path            => $fastq_path,
                id_run          => 1937,
                position        =>    3,
                ref_repository  => $ref_repos,
                request_list    => [ 'Vibrio_cholerae' ],
                aligner         => 'bowtie',
                aligner_options => 'ref=%ref% reads=%reads%',
                repository => $repos,
    );

    my $comm;
    lives_ok { $comm = $test->_align_command('Vibrio_cholerae'); } 'Call align method';

    my $expect = $bt
               . q{ ref=}   . $ref_repos . q{/Vibrio_cholerae/M66-2/all/bowtie/V_chol.fasta}
               . q{ reads=} . $test->temp_fastq();

    is( $comm, $expect, 'Aligner command is correctly constructed' );
}


{
    my $test = npg_qc::autoqc::checks::ref_match->new(
                path           => $fastq_path,
                id_run         => 1937,
                position       =>    3,
                ref_repository => $ref_repos,
                request_list   => ['Vibrio_cholerae'],
                repository => $repos,
    );

    my $sam =  't/data/autoqc/alignment_refmatch.sam';
    open my $fh , q[<], $sam;

    my $num_matches;
    lives_ok { $num_matches = $test->_parse_output($fh) } 'Call parse output method';
    is ($num_matches, 2, 'correct number of matches returned');
}

{
    my $test = npg_qc::autoqc::checks::ref_match->new(
                path           => $fastq_path,
                aligner_cmd    => join(q[/], q[does_not_exist], q[bowtie]),
                id_run         => 1937,
                position       =>    3,
                ref_repository => $ref_repos,
                request_list   => ['Vibrio_cholerae'],
                repository => $repos,
    );
    throws_ok {$test->execute} qr/Cannot fork \"does_not_exist\/bowtie/, 'error when cannot start an aligner';
}

{
    my $d = tempdir(CLEANUP => 1);
    my $bot = join q[/], $d, q[bowtie];

    my $test = npg_qc::autoqc::checks::ref_match->new(
                path           => $fastq_path,
                aligner_cmd    => $bot,
                id_run         => 1937,
                position       =>    3,
                ref_repository => $ref_repos,
                request_list   => ['Vibrio_cholerae'],
                repository => $repos,
    );

    open my $fh,  q[>], $bot;
    print $fh qq[ls dodo\n];
    close $fh;
    `chmod +x $bot`;

    throws_ok {$test->execute} qr/(exited with status 2)|(Cannot close bad pipe)/, 'error when aligner dies';
}

{
    my $test = npg_qc::autoqc::checks::ref_match->new(
                path           => $fastq_path,
                aligner_cmd    => $bt,
                id_run         => 1937,
                position       =>    3,
                ref_repository => $ref_repos,
                request_list   => ['Vibrio_cholerae'],
                repository => $repos,
    );

    lives_ok {$test->execute} 'execute lives';

    is_deeply( $test->result->aligned_read_count(), { 'Vibrio_cholerae' => 2 }, 'Correct match count saved' );
}

1;
