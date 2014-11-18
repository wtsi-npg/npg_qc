use strict;
use warnings;
use Carp;
use Test::More tests => 52;
use Test::Exception;
use Test::Deep;
use File::Temp qw(tempfile);
use DateTime;

use t::util;

BEGIN { use_ok 'npg_qc_viewer::Model::WarehouseDB' }

my $util = t::util->new();
my $schema_package = q[npg_warehouse::Schema];
my $fixtures_path = q[t/data/fixtures/warehouse];
my ($fh,$tmpdbfilename) = tempfile(UNLINK => 1);
my $schema;

lives_ok{ $schema = $util->create_test_db($schema_package, $fixtures_path, $tmpdbfilename) }
                              'test db created and populated';

$schema->resultset('NpgPlexInformation')->search({id_run => 4950, 'tag_index' => {'!=' => 0,},})->update({sample_id=>118118,});

my $m;
lives_ok {
  $m = npg_qc_viewer::Model::WarehouseDB->new( connect_info => {
                               dsn      => ('dbi:SQLite:'.$tmpdbfilename),
                               user     => q(),
                               password => q()
                                                               })
} 'create new model object';

isa_ok($m, 'npg_qc_viewer::Model::WarehouseDB');

{
    my $rs=$m->resultset(q(NpgInformation));
    ok (defined $rs, "NpgInformation resultset");
    ok ($rs->count, "NpgInformation resultset has data");
    $rs = $rs->search({id_run=>3500});
    cmp_ok($rs->count,'==',8, "lane count for run 3500");
}

{
    my $list = $m->samples_list();
    is (@{$list}, 26, '26 -  number of unique sample names returned');
    my @names = ();
    foreach my $s (@{$list}) { push @names, $s->{name}; };
    my $expected = '9837:A-J 500:AC0001C:AKR_J_1:B1267_Exp4:B3006_Exp4:B3009_Exp4:Exp2_PD2126a_WGA:Exp2_PD2126b_WGA:HG00367-B:Illumina phiX:NA07056-CEU:NA18545pd2a:NA18563pd2a:NA18623pd2a:NA18633pda:OX008_dscDNA:PD3682a:PD71-C_300:PG02-C_MDA_1:PG02-C_MDA_10:PG02-C_MDA_5:PH25-C_300:phiX CT1462-2 1:phiX_SI_SPRI:phiX_SI_SPRI 1';
    is (join(q[:], @names), $expected,'a sorted list of sample names');
}


{
    my $expected_studies = q[1000Genomes-B1-CHB:1000Genomes-B1-FIN:1000Genomes-B1-LWK:Anopheles gambiae genome variation 1:CGP Exome Resequencing:HumanEvolution2:ICR Exome Resequencing:Plasmodium ovale genome sequencing:Renal Cancer Exome];
    my $rs = $m->studies_list();
    is ($rs->count, 9, '9 -  number of unique project names returned');
    my @results = $rs->all;
    my @names = ();
    foreach my $r (@results) { push @names, $r->name };
    is (join(q[:], @names), $expected_studies ,'a sorted list of study names');
}


{
    my $rs = $m->libraries_list();
    is (scalar @{$rs}, 125, 'number of unique library names returned');
    my @names = ();
    foreach my $r (@{$rs}) { push @names, $r->asset_name };
    
    my @some_expected = (
    'AC0001C 1',
    'AKR_J_SLX_500_DSS_2',
    'B1267_Exp4 1',
    'B3006_Exp4 1',
    'B3009_Exp4 1',
    'Exp2_PD2126a_WGA 1',
    'Exp2_PD2126b_WGA 1',
    'phiX CT1462-2 1',
    '85T9N3 247036',
    '98T197N3 247058',
    'HG00367-B 400398');
    foreach my $l (@some_expected) {
      ok((grep /$l/, @names), qq['$l' library exists]);
    }
}


{
  my $row = $m->resultset('NpgInformation')->search({id_run=>1272, position=>1,})->next;
  is ($row->asset_id,  50313, 'asset id');
  is ($row->asset_name,  'PD3682a 1', 'asset name');
  is ($row->lane_type,  'library', 'lane type');
  is ($row->sample_id,  1322, 'sample id');
  is ($row->sample_name,  'PD3682a', 'sample name');
}


{
  my $row = $m->resultset('NpgInformation')->search({id_run=>4025, position=>6,})->next;
  is ($row->lane_type, 'library', 'lane type');
  is ($row->sample_id,  9387, 'sample id');
  is ($row->sample_name,  'NA18633pda', 'sample name');
  is ($row->study_id,  188, 'study id');
}

{
  my $row = $m->resultset('NpgInformation')->find({id_run=>4950, position=>6,});
  is ($row->lane_type, 'pool', 'lane type');
  is ($row->asset_id,  247826, 'asset id');
  is ($row->asset_name,  '506_pool_4', 'asset name');
  is ($row->sample_id,  undef, 'sample id');
  is ($row->sample_name,  undef, 'sample name');
}


{
  my $row = $m->resultset('NpgPlexInformation')->search({id_run=>4950, position=>1, tag_index=>0})->next;
  is ($row->asset_id, undef, 'asset id undef for tag_index=0');
  is ($row->asset_name, undef, 'asset name undef for tag_index=0');
  is ($row->sample_id, undef, 'sample id undef for tag_index=0');
  is ($row->sample_name,  undef, 'sample name undef for tag_index=0');
}

{
  my $row = $m->resultset('NpgPlexInformation')->search({id_run=>4950, position=>1, tag_index=>1})->next;
  is ($row->asset_id, 400398, 'asset id for a plex');
  is ($row->asset_name, 'HG00367-B 400398', 'asset name for a plex');
  is ($row->sample_id, 118118 , 'sample id for a plex');
  is ($row->sample_name,  'HG00367-B', 'sample name');
  is ($row->study_id,  383, 'study id');
}


{
  my $row = $m->resultset('CurrentSample')->search({internal_id => 9184,})->next;
  is($row->sample_name, 'Exp2_PD2126a_WGA', 'sample name');
}


{
  my $row = $m->resultset('NpgPlexInformation')->find({id_run=>4950, position=>1, tag_index=>1,});
  my $npg_row = $row->npg_info;
  ok ($npg_row, 'run-lane info retrieved ok');
  is ($npg_row->cycles, 224, 'cycle count 224');
  is ($row->rpt_key, q[4950:1:1], 'rpt key');
}

{
  my $row = $m->resultset('NpgInformation')->find({id_run=>4950, position=>1});
  is (ref $row->run_complete, 'DateTime', 'DateTime returned from a date column');
  is ($row->rpt_key, q[4950:1], 'rpt key');
}

1;





