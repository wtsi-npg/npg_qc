use strict;
use warnings;
use Template;
use Template::Plugin::Number::Format;
use Test::More tests => 2;

use npg_qc::autoqc::results::collection;
use npg_qc::autoqc::results::split_stats;
use npg_qc_viewer::api::util;

{
  my $tt = Template->new();
  my $template = q[root/src/ui_lanes/lanes_total.tt2];
  my $output = q[];

  my $c = npg_qc::autoqc::results::collection->new();
  $c->add_from_dir(q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive/qc]);
  $c->add(npg_qc::autoqc::results::split_stats->new(id_run=>1,position=>1));
  $tt->process($template, {
               util => npg_qc_viewer::api::util->new(),
               column_counter => 2, 
               checks_list => ['qX yield', 'split stats'], 
               collection_all => $c,
                          }, \$output);
  ok(!$tt->error(), 'template with input processed OK');
  my $row = q[<tr id="total">
  <td colspan="2" />
  <td class="total">2,799,102</td>    <td colspan="1" />
</tr>];

  is ($output, $row, 'total row ok');
}

1;
