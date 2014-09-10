use strict;
use warnings;
use Test::More tests => 12;
use Test::Exception;

use_ok('npg_qc::autoqc::role::result');

package npg_test::autoqc_result;
use Moose;
with 'npg_qc::autoqc::role::result';
no Moose;

package main;
{
  my $r = npg_test::autoqc_result->new();
  isa_ok($r, 'npg_test::autoqc_result');
  is(join(q[ ], $r->class_names()), 'autoqc_result AutoqcResult',
    'class names for this object returned');
  is(join(q[ ], npg_test::autoqc_result->class_names()), 'autoqc_result AutoqcResult',
    'class names for this package returned');
  throws_ok {npg_test::autoqc_result::class_names()} qr/No arguments/,
    'error in no arguments found';

  is(join(q[ ], $r->class_names('npg_qc::autoqc::upstream_tags')), 'upstream_tags UpstreamTags',
    'class names for the given argument returned');
  is(join(q[ ], npg_test::autoqc_result->class_names('npg_qc::autoqc::upstream_tags')), 'upstream_tags UpstreamTags',
    'class names for the given argument returned');
  is(join(q[ ], npg_qc::autoqc::role::result->class_names('npg_qc::autoqc::upstream_tags')), 'upstream_tags UpstreamTags',
    'class names for the given argument returned');
  is(join(q[ ], npg_test::autoqc_result::class_names('npg_qc::autoqc::upstream_tags')), 'upstream_tags UpstreamTags',
    'class names for the given argument returned');

  is(join(q[ ], $r->class_names('npg_qc::autoqc::results::qX_yield-16446')),
    'qX_yield QXYield', 'correct class names returned from json class value');
  is(join(q[ ], $r->class_names('npg_qc::autoqc::results::tag_decode_stats-8829')),
    'tag_decode_stats TagDecodeStats', 'correct class names returned from json class value');
  is(join(q[ ], $r->class_names('qX_yield')),
    'qX_yield QXYield', 'correct class names returned from class name');
}

1;

