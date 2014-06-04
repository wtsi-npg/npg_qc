#########
# Author:        ajb
# Created:       2008-11-23
#

use strict;
use warnings;
use Test::More 'no_plan';#tests => 4;
use English qw(-no_match_vars);
use IO::Scalar;
use t::util;

use_ok('npg_qc::model::image_store');
my $util = t::util->new({fixtures => 1});
{
  my $image_store = npg_qc::model::image_store->new({
      util => $util,
      id_run => 1,
      type => 'errors_by_cycle',
      image_name => '1_1_52.png',
      thumbnail => 0,
  });
  isa_ok($image_store, 'npg_qc::model::image_store', '$image_store');
  is($image_store->id_image_store(), 1, 'retrieved id_image_store');
  is($image_store->image(), 'an_image', 'retrieved image ok');
}
{
  my $image_store = npg_qc::model::image_store->new({
      util => $util,
      id_run => 2,
      type => 'errors_by_cycle',
      image => 'test',
      image_name => '2_2_10.png',
      thumbnail => 1,
      suffix => 'png',
  });

  is($image_store->id_image_store(), undef, 'does not exist');
  $image_store->save();
  is($image_store->id_image_store(), 2, 'saved');
  $image_store->image('new_test');
  eval { $image_store->save(); };
  is($EVAL_ERROR, q{}, 'no croak on update');
  $image_store->id_image_store(undef);
  eval { $image_store->save(); };
  like($EVAL_ERROR, qr{DBD::mysql::db do\ failed:\ Duplicate entry\ '2-errors_by_cycle-1-2_2_10.png'\ for\ key\ 'unq_idx_rt_type_thbnl_in'}, 'expecting to croak to due to attempt to save the same unique value set');
}
__END__
   type: errors_by_cycle
   thumbnail: 0
   image: an_image
   image_name: 1_1_52.png
   id_run: 1
   suffix: png
