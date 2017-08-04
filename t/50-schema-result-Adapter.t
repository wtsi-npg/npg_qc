use strict;
use warnings;
use Test::More tests => 16;
use Test::Exception;
use Test::Deep;
use Moose::Meta::Class;
use JSON;

use npg_testing::db;
use t::autoqc_util;

use_ok('npg_qc::Schema::Result::Adapter');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

my $json = 
q { {
  "position":"1",
  "reverse_start_counts":{"33":5,"32":5,"21":3,"26":3,"17":3,"2":1,"1":865,"18":2,"30":4,"16":3,"44":19,"25":4,"27":3,"28":3,"40":8,"20":9,"24":5,"31":4,"35":6,"22":1,"42":6,"46":20,"23":1,"29":6,"39":19,"36":8,"3":1,"12":1,"41":16,"15":37,"8":1,"38":7,"4":11,"34":5,"45":13,"37":7,"19":4,"43":19},
  "forward_read_filename":"/nfs/sf19/ILorHSany_sf19/analysis/130125_HS23_09225_B_C1CBDACXX/Data/Intensities/BAM_basecalls_20130203-192218/PB_cal_bam/lane1/9225_1#95.bam",
  "reverse_fasta_read_count":28220671,
  "info":{"Check":"npg_qc::autoqc::checks::adapter","Check_version":"16569"},
  "forward_blat_hash":{"RP1":0,"PE-sequencingPrimer1":1,"DpnII-Gex-Adapter2-1":0,"NlaIII-Gex-PCR-Primer1":0,"smallRNA-3'adapter":0,"long-insert-2-internal-3'":0,"DpnII-Gex-Adapter1-1":0,"RA5":0,"PE-sequencingPrimer2":27701,"DpnII-Gex-SequencingPrimer":0,"adaptor3":1,"genomicDNA=primer2":0,"smallRNA-5'adapter":0,"PE-adapters1-2":1,"NlaIII-Gex-Adapter2-1":0,"genomicDNA-primer1":1,"NlaIII-Gex-Adapter1-1":0,"long-insert-2-internal-5'":0,"DpnII-Gex-PCR-Primer2":0,"smallRNA-PCS-primer1":0,"smallRNA-RT-primer":0,"NlaIII-Gex-Adapter2-2":0,"adaptor4":27713,"hybrid-internal-3'adapter":0,"Nextflex-barcode(degenerate)":0,"TruSeq-Small-RNA-5'adapter":0,"NlaIII-Gex-Adapter1-2":0,"Nextflex-PCR-2":0,"NlaIII-Gex-PCR-Primer2":0,"adaptor2":0,"DpnII-Gex-Adapter1-2":0,"genomicDNA-adapter2":1,"TruSeq-Adapter-Index-2":0,"PE-PCR-Primers1-1":1,"TruSeq-Universal-Adapter":1,"genomicDNA-sequencingPrimer":1,"PE-PCR-Primers1-2":27713,"PE-adapters1-1":27148,"smallRNA-sequencingPrimer":0,"NlaIII-Gex-SequencingPrimer":0,"TruSeq-Small-RNA-3'adapter":0,"adaptor1":26364,"DpnII-Gex-PCR-Primer1":0,"smallRNA-PCS-primer2":0,"genomicDNA-adapter1":0,"Nextflex-PCR-1":0,"DpnII-Gex-Adapter2-2":0,"hybrid-internal-5'adapter":0},
  "forward_contaminated_read_count":27725,
  "forward_fasta_read_count":28220671,
  "path":"/nfs/sf19/ILorHSany_sf19/analysis/130125_HS23_09225_B_C1CBDACXX/Data/Intensities/BAM_basecalls_20130203-192218/PB_cal_bam/lane1",
  "id_run":"9225",
  "tag_index":"95",
  "reverse_contaminated_read_count":1138,
  "reverse_blat_hash":{"RP1":0,"PE-sequencingPrimer1":741,"DpnII-Gex-Adapter2-1":0,"NlaIII-Gex-PCR-Primer1":0,"smallRNA-3'adapter":0,"long-insert-2-internal-3'":0,"DpnII-Gex-Adapter1-1":0,"RA5":0,"PE-sequencingPrimer2":7,"DpnII-Gex-SequencingPrimer":0,"adaptor3":1129,"genomicDNA=primer2":0,"smallRNA-5'adapter":0,"PE-adapters1-2":741,"NlaIII-Gex-Adapter2-1":0,"genomicDNA-primer1":1129,"NlaIII-Gex-Adapter1-1":0,"long-insert-2-internal-5'":0,"DpnII-Gex-PCR-Primer2":0,"smallRNA-PCS-primer1":0,"smallRNA-RT-primer":0,"NlaIII-Gex-Adapter2-2":0,"adaptor4":7,"hybrid-internal-3'adapter":0,"Nextflex-barcode(degenerate)":0,"TruSeq-Small-RNA-5'adapter":0,"NlaIII-Gex-Adapter1-2":0,"Nextflex-PCR-2":0,"NlaIII-Gex-PCR-Primer2":0,"adaptor2":0,"DpnII-Gex-Adapter1-2":0,"genomicDNA-adapter2":741,"TruSeq-Adapter-Index-2":0,"PE-PCR-Primers1-1":1129,"TruSeq-Universal-Adapter":1129,"genomicDNA-sequencingPrimer":741,"PE-PCR-Primers1-2":7,"PE-adapters1-1":7,"smallRNA-sequencingPrimer":0,"NlaIII-Gex-SequencingPrimer":0,"TruSeq-Small-RNA-3'adapter":0,"adaptor1":0,"DpnII-Gex-PCR-Primer1":0,"smallRNA-PCS-primer2":0,"genomicDNA-adapter1":0,"Nextflex-PCR-1":0,"DpnII-Gex-Adapter2-2":0,"hybrid-internal-5'adapter":0},
  "reverse_read_filename":"/nfs/sf19/ILorHSany_sf19/analysis/130125_HS23_09225_B_C1CBDACXX/Data/Intensities/BAM_basecalls_20130203-192218/PB_cal_bam/lane1/9225_1#95.bam",
  "forward_start_counts":{"33":9,"32":17,"21":6,"26":3,"2":36,"17":4,"1":26722,"18":8,"30":10,"16":2,"44":21,"25":5,"27":3,"28":12,"40":9,"20":445,"24":9,"31":9,"35":7,"22":1,"42":7,"46":21,"23":2,"29":6,"39":19,"3":2,"36":8,"9":4,"12":1,"41":18,"15":38,"8":1,"38":8,"4":196,"34":5,"37":7,"45":15,"19":7,"43":19,"5":3}}
  };

my $rs = $schema->resultset('Adapter');
my $values = from_json($json);
$values->{'id_seq_composition'} =
  t::autoqc_util::find_or_save_composition($schema,
    {id_run => 9225, position => 1, tag_index => 95});

{
  my %values1 = %{$values};
  my $v1 = \%values1;
  isa_ok($rs->new_result($v1), 'npg_qc::Schema::Result::Adapter');

  lives_ok {$rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()}
    'tag record inserted';
  my $rs1 = $rs->search({});
  is ($rs1->count, 1, q[one row created in the table]);  
  my $row = $rs1->next;
  is(ref $row->forward_start_counts, 'HASH', 'forward_start_counts column value returned as a hash');
  cmp_deeply($row->forward_start_counts, $values->{'forward_start_counts'},
    'contaminant_count ref hash content is correct');

  $v1 = \%values1; 
  delete $v1->{'id_run'};
  delete $v1->{'position'};
  delete $v1->{'tag_index'};
  my $row1;
  lives_ok {$row1 = $rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()}
    'another or the same row?';
  is ($row->id_adapter, $row1->id_adapter, 'new row is not created');

  $v1->{'id_seq_composition'} =
  t::autoqc_util::find_or_save_composition($schema,
    {id_run => 9225, position => 1, tag_index => 96});
  lives_ok {$row1 = $rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()}
    'another row';
  isnt ($row->id_adapter, $row1->id_adapter, 'new row is created');
  is ($row1->id_run, undef, 'id run value is undefined');
  is ($row1->position, undef, 'position value is undefined');
  is ($row1->tag_index, undef, 'tag_index value is undefined');
}

{
  my %values1 = %{$values};
  my $v1 = \%values1;
  delete $v1->{'reverse_blat_hash'};
  $v1->{'reverse_read_filename'} = 'new_name';
  lives_ok {$rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()}
    'tag record updated';
  is($rs->search({})->next->reverse_read_filename, 'new_name', 'scalar field correctly updated');
  cmp_deeply($rs->search({})->next->reverse_blat_hash, $values->{'reverse_blat_hash'}, 
      qq[reverse_blat_hash not provided - column not updated]);
}

1;


