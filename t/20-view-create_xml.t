#########
# Author:        ajb
# Created:       2008-06-16
#

use strict;
use warnings;
use Test::More tests => 34;
use English qw(-no_match_vars);
use IO::Scalar;
use t::util;

use_ok('npg_qc::view::create_xml');

my $util = t::util->new({fixtures => 1});
my $bustard_config_xml = $util->rendered('t/data/rendered/bustard_config.xml');
my $tile_score_xml     = $util->rendered('t/data/rendered/tile_score_xml.xml');
my $tile_all_xml       = $util->rendered('t/data/rendered/tile_all.xml');
my $signal_mean_xml    = $util->rendered('t/data/rendered/signal_means.xml');

{
  my $view = npg_qc::view::create_xml->new({util => $util});
  isa_ok($view, 'npg_qc::view::create_xml', '$view');

  is($view->decor(), 0, '$view->decor() returns 0');
  is($view->content_type(), 'application/xml', '$view->content_type() is application/xml');
  my $render;

  my $bustard_parsed = $view->parse_xml($bustard_config_xml);
  isa_ok($bustard_parsed, 'HASH', '$view->parse_xml($bustard_config_xml)');
  is($bustard_parsed->{dataset}, 'run_config', 'dataset is run_config');
  isa_ok($bustard_parsed->{attributes}, 'HASH', '$bustard_parsed->{attributes}');
  is($bustard_parsed->{attributes}->{id_run}, 812, '$bustard_parsed->{attributes}->{id_run} ok');
  like($bustard_parsed->{attributes}->{config_text}, qr{\A\#\ Auto\-generated\ by\;}, '$bustard_parsed->{attributes}->{config_text} start ok');
  like($bustard_parsed->{attributes}->{config_text}, qr{4\:USE_BASES\ Y36\n\n\z}, '$bustard_parsed->{attributes}->{config_text} end ok');

  my $response;
  eval { $response = $view->run_config($bustard_parsed); };
  is($EVAL_ERROR, q{}, 'no croak on $view->run_config($bustard_parsed)');
  is($response, '<?xml version="1.0" encoding="utf-8"?><sent_type>run_config</sent_type>', '$response ok');
  my $signal_mean_parsed = $view->parse_xml($signal_mean_xml);
  my $dataset = $signal_mean_parsed->find('root/dataset')->string_value;
  cmp_ok($dataset, 'eq', 'signal_mean', q{$signal_mean_parsed->getElementsByTagName('dataset') is signal_mean});
  my $run = $signal_mean_parsed->getElementsByTagName('run')->shift();
  is($run->getAttribute('id_run'), 812, 'id_run obtained ok');
  my $lanes_node = $run->getElementsByTagName('lanes')->shift();
  my @lanes = $lanes_node->getElementsByTagName('lane');
  is(scalar@lanes, 8, '8 lanes found');
  my $lane = pop@lanes;
  is($lane->getAttribute('position'), 8, 'position obtained ok');
  my $signal_means = $lane->getElementsByTagName('signal_means')->shift();
  my @rows = $signal_means->getElementsByTagName('row');
  is(scalar@rows, 36, '36 rows for 1 lane');
  my $row = pop@rows;
  is($row->getAttribute('call_a'), '3888.0', 'row call_a obtained ok');
  eval{ $response = $view->signal_mean($signal_mean_parsed); };
  is($EVAL_ERROR, q{}, 'no croak on $view->signal_mean($signal_mean_parsed)');
  is($response, '<?xml version="1.0" encoding="utf-8"?><sent_type>signal_mean</sent_type>', '$response ok');

  my $tile_score_parsed = $view->parse_xml($tile_score_xml);
  $dataset = $tile_score_parsed->find('root/dataset')->string_value;
  cmp_ok( $dataset, 'eq', 'tile_score', q{$tile_score_parsed->getElementsByTagName('dataset') is tile_score});
  eval{ $response = $view->tile_score($tile_score_parsed); };
  is($EVAL_ERROR, q{}, 'no croak on $view->tile_score($tile_score_parsed)');
  is($response, '<?xml version="1.0" encoding="utf-8"?><sent_type>tile_score</sent_type>', '$response ok');
}

{
  my $cgi = $util->cgi();
  $cgi->param('XForms:Model', $bustard_config_xml);
  my $view = npg_qc::view::create_xml->new({util => $util});
  my $render;
  eval{ $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak on $view->render() for bustard_config data');
  is($render, '<?xml version="1.0" encoding="utf-8"?><sent_type>run_config</sent_type>', '$view->render() ok');
}

$util = t::util->new({fixtures => 1});

{
  my $summary_xml = $util->rendered('t/data/rendered/summary.xml');
  my $cgi = $util->cgi();
  $cgi->param('XForms:Model', $summary_xml);
  my $view = npg_qc::view::create_xml->new({util => $util});
  my $render;
  eval{ $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak on $view->render() for summary data');
  is($render, '<?xml version="1.0" encoding="utf-8"?><sent_type>summary_data</sent_type>', '$view->render() ok');
}
{
  my $summary_xml = $util->rendered('t/data/rendered/first_reprocessed_summary.xml');
  my $cgi = $util->cgi();
  $cgi->param('XForms:Model', $summary_xml);
  my $view = npg_qc::view::create_xml->new({util => $util});
  my $render;
  eval{ $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak on $view->render() for first_reprocessed_summary data');
  is($render, '<?xml version="1.0" encoding="utf-8"?><sent_type>summary_data</sent_type>', '$view->render() ok');

  $summary_xml = $util->rendered('t/data/rendered/second_reprocessed_summary.xml');
  $cgi->param('XForms:Model', $summary_xml);
  $view = npg_qc::view::create_xml->new({util => $util});
  eval{ $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak on $view->render() for second_reprocessed_summary data');
  is($render, '<?xml version="1.0" encoding="utf-8"?><sent_type>summary_data</sent_type>', '$view->render() ok');
  my $lane_qc = npg_qc::model::lane_qc->new({util => $util});
  my $before_resubmission = scalar@{$lane_qc->lane_qcs};
  eval{ $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak on $view->render() for second_reprocessed_summary data');
  is(scalar@{$lane_qc->lane_qcs}, $before_resubmission, 'resubmitting has not added any additional rows');

  $view = npg_qc::view::create_xml->new({util => $util});
  eval{ $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak on update of lane qc data');
}

1;
__END__
