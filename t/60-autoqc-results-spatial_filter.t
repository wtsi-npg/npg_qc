#########
# Author:        dj3
# Maintainer:    $Author: mg8 $
# Created:       2009-09-21
# Last Modified: $Date: 2011-08-23 17:46:49 +0100 (Tue, 23 Aug 2011) $
# Id:            $Id: 60-autoqc-results-tag_decode_stats.t 14027 2011-08-23 16:46:49Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/branches/prerelease-51.0/t/60-autoqc-results-tag_decode_stats.t $
#

use strict;
use warnings;
use Test::More tests => 24;
use Test::Exception;
use File::Temp qw/ tempdir /;
use Perl6::Slurp;
use JSON;
use Carp;
use Cwd;

use_ok ('npg_qc::autoqc::results::spatial_filter');

my $tempdir = tempdir( CLEANUP => 0);
{
    my $r = npg_qc::autoqc::results::spatial_filter->new({
                                       position => 1,
                                       id_run   => 8926,
                                 });
    isa_ok ($r, 'npg_qc::autoqc::results::spatial_filter');

    my $stats_output_string = slurp 't/data/autoqc/PB_cal_score_8926_1_20121209-190404.494308.out';
    $r->parse_output(\$stats_output_string);    

    is($r->num_total_reads, 2*209837769, 'total reads');    
    is($r->num_spatial_filter_fail_reads, 0, 'spatial filter fail reads');    

    lives_ok {
      $r->freeze();
      $r->store(qq{$tempdir/spatial_filter_1.json});
    } 'no croak when save data into json'; 
    
}

{
    my $r = npg_qc::autoqc::results::spatial_filter->new({
                                       position => 2,
                                       id_run   => 8926,
                                 });
    isa_ok ($r, 'npg_qc::autoqc::results::spatial_filter');

    open my $stats_output_fh, '<', 't/data/autoqc/PB_cal_score_8926_2_20121209-190404.494309.out' or croak 'fail to open fh';
    lives_ok {
      local *STDIN=$stats_output_fh;
      $r->parse_output();
    } 'parse from (pseudo) stdin';
    close $stats_output_fh or croak 'fail to close fh';    

    is($r->num_total_reads, 439161826, 'total reads');    
    is($r->num_spatial_filter_fail_reads, 358824, 'spatial filter fail reads');    
    
    lives_ok {
      $r->freeze();
      $r->store($tempdir);
    } 'no croak when save data into json (store passed directory)';

    my $hash = from_json( slurp qq{$tempdir/8926_2.spatial_filter.json} );

    my $expected_hash_structure = {
      'num_total_reads' => 439161826,
      'num_spatial_filter_fail_reads' => 358824,
      'id_run' => 8926,
      'info' => {},
      'position' => 2,
    };

    ok( exists $hash->{__CLASS__}, q{__CLASS__ key found} );
    delete $hash->{__CLASS__};

    is_deeply( $hash, $expected_hash_structure, q{expected results obtained} );
}

{
    my $r = npg_qc::autoqc::results::spatial_filter->new({
                                       position => 3,
                                       id_run   => 8926,
                                 });
    isa_ok ($r, 'npg_qc::autoqc::results::spatial_filter');

    lives_ok {
      my$s='';
      $r->parse_output(\$s);
    } 'parse from empty string';

    is($r->num_total_reads, undef, 'total reads');
    is($r->num_spatial_filter_fail_reads, undef, 'spatial filter fail reads');

    lives_ok {
      my $odir = getcwd();
      chdir $tempdir;
      $r->store();
      chdir $odir;
    } 'no croak when save data into json';
}

{
    my $r = npg_qc::autoqc::results::spatial_filter->new({
                                       position => 4,
                                       id_run   => 8926,
                                 });
    isa_ok ($r, 'npg_qc::autoqc::results::spatial_filter');

    open my $stats_output_fh, '<', 't/data/autoqc/PB_cal_score_8926_4_20121209-190404.494309.out' or croak 'fail to open fh';
    lives_ok {
      local *STDIN=$stats_output_fh;
      $r->parse_output();
    } 'parse from (pseudo) stdin';
    close $stats_output_fh or croak 'fail to close fh';

    is($r->num_total_reads, 439161826, 'total reads');
    is($r->num_spatial_filter_fail_reads, 358824, 'spatial filter fail reads');

    lives_ok {
      $r->freeze();
      $r->store($tempdir);
    } 'no croak when save data into json (store passed directory)';

    my $hash = from_json( slurp qq{$tempdir/8926_4.spatial_filter.json} );

    my $expected_hash_structure = {
      'num_total_reads' => 439161826,
      'num_spatial_filter_fail_reads' => 358824,
      'id_run' => 8926,
      'info' => {},
      'position' => 4,
    };

    ok( exists $hash->{__CLASS__}, q{__CLASS__ key found} );
    delete $hash->{__CLASS__};

    is_deeply( $hash, $expected_hash_structure, q{expected results obtained} );
}


1;
