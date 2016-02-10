use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;
use List::MoreUtils 'all';

use_ok 'npg_qc_viewer::Util::CompositionFactory';

{
  throws_ok {npg_qc_viewer::Util::CompositionFactory->new()}
    qr/Attribute \(rpt_list\) is required /,
    'rpt_list attribute should be set';

  my $f;
  lives_ok {$f = npg_qc_viewer::Util::CompositionFactory->new(
                   rpt_list => '1:2:3;4:4;6:7:8'
           )} 'object created';
  isa_ok($f, 'npg_qc_viewer::Util::CompositionFactory');
  my $composition = $f->create_composition();
  isa_ok($composition, 'npg_tracking::glossary::composition');
  my @types = map {ref $_} @{$composition->components};
  is((scalar @types), 3, 'three components');
  ok((all {$_ eq 'npg_tracking::glossary::composition::component::illumina'} @types),
    'components have correct type');
}

1;