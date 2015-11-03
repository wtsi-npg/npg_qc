use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;
use Test::Deep;
use Moose::Meta::Class;
use JSON;
use npg_testing::db;

use_ok('npg_qc::Schema::Result::GcBias');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

  my $table = 'GcBias';

my $json = q { 
{
  "window_count":72800,
  "max_y":871.65,
  "position":"1",
  "plot_x":["1.678571","23.41484","53.81181","74.56044","86.39148","92.9011","96.91071","98.91209","99.68819","99.93956","99.99725"],
  "ideal_lower_quantile":["32","47","71","94","106","138","200","249","257","237","296"],
  "plot_y":["40.46352","56.75126","82.9343","106.8969","120.3766","154.2603","219.0115","269.9763","278.3773","257.3","318.85"],
  "window_size":30000,"bin_count":11,
  "info":{"Check":"npg_qc::autoqc::checks::gc_bias","Check_version":"16569"},
  "actual_quantile_x":["1.678571","23.41484","53.81181","74.56044","86.39148","92.9011","96.91071","98.91209","99.68819","99.93956","99.99725","99.99725","99.93956","99.68819","98.91209","96.91071","92.9011","86.39148","74.56044","53.81181","23.41484","1.678571"],
  "path":"/nfs/sf19/ILorHSany_sf19/analysis/130125_HS23_09225_B_C1CBDACXX/Data/Intensities/BAM_basecalls_20130203-192218/PB_cal_bam/archive/lane1",
  "id_run":"9225",
  "tag_index":"0",
  "actual_quantile_y":["125","194","279","343.5","373","434","545.9","644","627.8","548.7","670.5","83.8","38","34","28","20","14","10","8","6","4","2.5"],
  "gc_lines":["NA","NA","NA","NA","64.18613","94.9059","99.81387","NA","NA","NA","NA"],
  "cached_plot":"data"
 } 
};

my $values = from_json($json);
my $rs = $schema->resultset('GcBias');
isa_ok($rs->new_result($values), 'npg_qc::Schema::Result::GcBias');

{
  my %values1 = %{$values};
  my $v1 = \%values1;

  $rs->deflate_unique_key_components($v1);
  is($v1->{'tag_index'}, 0, 'tag index zero not deflated');
  lives_ok {$rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()} 'tag zero record inserted';
  my $rs1 = $rs->search({});
  is ($rs1->count, 1, q[one row created in the table]);
  my $row = $rs1->next;
  is($row->tag_index, 0, 'tag index zero retrieved correctly');
  is(ref $row->actual_quantile_y, 'ARRAY', 'actual_quantile_y returned as an array');
  cmp_deeply($row->actual_quantile_y, $values->{'actual_quantile_y'},
    'actual_quantile_y array content is correct');  
}

1;
