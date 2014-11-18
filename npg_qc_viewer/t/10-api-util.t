use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;

use npg_qc::autoqc::results::collection;

use t::util;

local $ENV{TEST_DIR} = t::util->new()->staging_path;

use_ok 'npg_qc_viewer::api::util';

{ isa_ok(npg_qc_viewer::api::util->new(), 'npg_qc_viewer::api::util'); }

{
  my $total = 46;
  my $c = npg_qc::autoqc::results::collection->new();
  $c->add_from_staging(4025);
  is ($c->size, $total, qq[$total results in the collection]);
  my $rl_map = $c->run_lane_collections;
  
  my $api_util = npg_qc_viewer::api::util->new();
  my $reconstructed = $api_util->rl_map2collection($rl_map);
  is ($reconstructed->size, $total, qq[$total results in the reconstructed collection]);
}

1;



  

