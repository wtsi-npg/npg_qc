#########
# Author:        ajb
# Maintainer:    $Author$
# Created:       2008-06-16
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 11;
use English qw(-no_match_vars);
use IO::Scalar;
use t::util;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mx; $r; };

use_ok('npg_qc::model::main');
use_ok('npg_qc::model::create_xml');

my $util = t::util->new({ fixtures => 1 });
{
  my $create_xml_model = npg_qc::model::create_xml->new({util => $util});
  isa_ok($create_xml_model, 'npg_qc::model::create_xml', '$create_xml_model');
}
{
  my $main_model = npg_qc::model::main->new({util => $util});
  isa_ok($main_model, 'npg_qc::model::main', '$main_model');
  my $run_configs = $main_model->run_configs();
  isa_ok($run_configs, 'ARRAY', '$main_model->run_configs()');
  is($main_model->run_configs(), $run_configs, '$main_model->run_configs() cached ok');
  my $id_runs = $main_model->id_runs();
  isa_ok($id_runs, 'ARRAY', '$main_model->id_runs()');
  is($main_model->id_runs(), $id_runs, '$main_model->id_runs() cached ok');
  my $illumina_data_runs = $main_model->illumina_data_runs();
  isa_ok($illumina_data_runs, 'ARRAY', '$main_model->illumina_data_runs()');
  is($main_model->illumina_data_runs(), $illumina_data_runs, '$main_model->illumina_data_runs() cached ok');
  is(@{[$main_model->displays()]}[0], 'swift_summary', 'First element of returned array from $main_model->displays() is swift_summary');
}
