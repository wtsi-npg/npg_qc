#########
# Author:        gq1
# Maintainer:    $Author$
# Created:       2009-09-21
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 14;
use Test::Exception;
use File::Temp qw/ tempdir /;
use Perl6::Slurp;
use JSON;


use_ok ('npg_qc::autoqc::results::tag_decode_stats');

my $tempdir = tempdir( CLEANUP => 0);
{
    my $r = npg_qc::autoqc::results::tag_decode_stats->new({
                                       position => 8,
                                       id_run   => 4360,
                                 });
    isa_ok ($r, 'npg_qc::autoqc::results::tag_decode_stats');

    my $stats_output_string = slurp 't/data/autoqc/tag_decode_output.txt';
    $r->parsing_output_string($stats_output_string);    
    
    lives_ok {
      $r->freeze();
      $r->store(qq{$tempdir/split_stats.json});
    } 'no croak when save data into json'; 
    
}

## tests when the decoded tags might not be found
{
    my $r = npg_qc::autoqc::results::tag_decode_stats->new({
                                       position => 8,
                                       id_run   => 4360,
                                 });
    isa_ok ($r, 'npg_qc::autoqc::results::tag_decode_stats');

    my $stats_output_string = slurp 't/data/autoqc/tag_decode_output_no_found_tags.txt';
    $r->parsing_output_string($stats_output_string);    
    
    lives_ok {
      $r->freeze();
      $r->store(qq{$tempdir/split_stats_no_tags_found.json});
    } 'no croak when save data into json';

    my $hash = from_json( slurp qq{$tempdir/split_stats_no_tags_found.json} );

    my $expected_hash_structure = {
      'distribution_all' => {},
      'distribution_good' => {},
      'errors_all' => {
        '0' => '304354',
        '1' => '6627',
        'no_match' => '7512'
      },
      'errors_good' => {
        '0' => '275562',
        '1' => '1505',
        'no_match' => '2078'
      },
      'id_run' => 4360,
      'info' => {},
      'pass' => 0,
      'position' => 8,
      'tag_code' => {}
    };

    ok( exists $hash->{__CLASS__}, q{__CLASS__ key found} );
    delete $hash->{__CLASS__};

    is_deeply( $hash, $expected_hash_structure, q{expected results obtained} );
}

{
  my $result = npg_qc::autoqc::results::tag_decode_stats->load(q[t/data/autoqc/4360_8_tag_decode_stats.json]);
  is ($result->has_spiked_phix_tag, 0, 'result does not contain spiked phix tag');
  throws_ok { $result->variance_coeff(q[bad]) } qr/Unexpected distribution type bad/, 'error when distribution key is not from a list of allowed values';
  is (int($result->variance_coeff(q[good])), 45, 'cv good');
  is (int($result->variance_coeff(q[all])), 45, 'cv all');

  $result = npg_qc::autoqc::results::tag_decode_stats->load(q[t/data/autoqc/tag_decode_stats/6624_3_tag_decode_stats.json]);
  is ($result->has_spiked_phix_tag, 1, 'result contains spiked phix tag');
  is (int($result->variance_coeff(q[good])), 9, 'cv good');
  is (int($result->variance_coeff(q[all])), 8, 'cv all');
}

1;
