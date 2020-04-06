use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;

use npg_tracking::glossary::composition::component::illumina;
use npg_tracking::glossary::composition;

use_ok('npg_qc::autoqc::results::review');

my $composition = npg_tracking::glossary::composition->new(
  components => [
    npg_tracking::glossary::composition::component::illumina->new(
      id_run => 1, position => 1, tag_index => 3,
    ),
    npg_tracking::glossary::composition::component::illumina->new(
      id_run => 1, position => 2, tag_index => 3,
    )
  ]
);

my $r = npg_qc::autoqc::results::review->new(composition => $composition);
isa_ok ($r, 'npg_qc::autoqc::results::review');
$r->qc_outcome({mqc_outcome => 'Accepted_final',
                timestamp   => '2019-05-23T17:11:31+0100',
                username    => 'robo_qc'});
is ($r->criteria_md5, undef, 'criteria_md5 is not defined');
$r->criteria({'and' => [qw/expressionA expressionB/]});
$r->evaluation_results({expressionA => 1, expressionB => 1});
is ($r->criteria_md5, undef, 'criteria_md5 is not defined');

my $frozen;
lives_ok { $frozen = $r->freeze } 'object can be serialized';
lives_ok { $r = npg_qc::autoqc::results::review->thaw($frozen) }
  'JSON serialization can be deserialized back into an object';

1;
