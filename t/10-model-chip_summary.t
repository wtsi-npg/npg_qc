#########
# Author:        ajb
# Maintainer:    $Author$
# Created:       2008-07-21
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;
use t::util;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mx; $r; };

use_ok('npg_qc::model::chip_summary');

my $util = t::util->new({fixtures =>1});
{
  my $model = npg_qc::model::chip_summary->new({util => $util});
  isa_ok($model, 'npg_qc::model::chip_summary', '$model');

  lives_ok { npg_qc::model::chip_summary->new({
      util            => $util,
      id_chip_summary => 1,
    }) } 'model created ok with a id_chip_summary';

  lives_ok { npg_qc::model::chip_summary->new({
      util            => $util,
      id_run          => 1,
    }) } 'model created ok with a id_run';
}
{
  my $model;
  lives_ok { $model = npg_qc::model::chip_summary->new({
      util            => $util,
      id_run          => 1,
      id_chip_summary => 1,
    }) } 'model created ok with a id_run and a id_chip_summary';

  is (join(q[ ], $model->qcal_total), '15509090 10555475 7667988', 'total q values');
  
  my $expected = { '1' => {'q20' => { '1' => 1735548,}, 'q25' => { '1' => 1267812,}, 'q30' => { '1' => 1033943,},},
                   '2' => {'q20' => { '1' => 0, '2' => 13773542, }, 'q25' => { '1' => '-', '2' => 9287663,}, 'q30' => { '1' => '-', '2' => 6634045,},},
		 };
  is_deeply($model->qcal_by_lane(), $expected, 'individual q values as a hash');
}

1;
