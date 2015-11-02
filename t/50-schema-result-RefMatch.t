use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;
use Test::Deep;
use Moose::Meta::Class;
use JSON;
use npg_testing::db;

use_ok('npg_qc::Schema::Result::RefMatch');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

  my $table = 'RefMatch';

my $json = q { 
  {
  "info":{"Check":"npg_qc::autoqc::checks::ref_match","Check_version":"16569"},
  "sample_read_count":10000,
  "sample_read_length":37,"position":"1","path":"/nfs/sf19/ILorHSany_sf19/analysis/130125_HS23_09225_B_C1CBDACXX/Data/Intensities/BAM_basecalls_20130203-192218/PB_cal_bam/archive/lane1","id_run":"9225",
  "reference_version":
  {
    "Bacillus_thuringiensis":"Bt407","Human_herpesvirus_8":"NC_009333","Vibrio_cholerae":"M66-2","Drosophila_melanogaster":"Release_5","Streptococcus_pyogenes":"Manfredo","Gorilla_gorilla":"gorilla","Saccharomyces_cerevisiae":"S288c_SGD2012","Chlamydophila_abortus":"S26_3","Streptococcus_uberis":"0140J","Mycobacterium_abscessus":"CU458896.1","Trypanosoma_brucei":"927_230210","Plasmodium_berghei":"ANKA","Strongyloides_ratti":"20100601","Giardia_intestinalis":"assemblage_A","Melissococcus_plutonius":"ATCC_35311","Tupaia_belangeri":"GCA_000181375.1","Tursiops_truncatus":"GCA_000151865.2","Aspergillus_fumigatus":"Af293","Streptococcus_pneumoniae":"ATCC_700669","Shigella_boydii":"CDC_3083-94","Human_herpesvirus_1":"strain_17","Mycobacterium_bovis":"AF2122_97","Rhesus_macaque":"GCA_000230795.1","Human_herpesvirus_5":"AD169",
"Haemophilus_parasuis":"SH0165","Pseudomonas_aeruginosa":"PAO1","Yersinia_enterocolitica":"enterocolitica_8081","Leishmania_major":"V5.2","Burkholderia_pseudomallei":"K96243","Bordetella_bronchiseptica":"RB50","Human_herpesvirus_6":"U1102","Trichuris_muris":"v281111","Xenopus_tropicalis":"Wild_type","Leptospira_interrogans":"serovar_Copenhageni","Plasmodium_knowlesi":"strainH","Hymenolepis_microstoma":"Hmicrostoma_v1.sl","Streptomyces_coelicolor":"A3_2_","Klebsiella_pneumoniae":"NC_011283","Serratia_proteamaculans":"568","Cryptosporidium_parvum":"Iowa_II","Sus_scrofa":"GCA_000003025.4","Lactobacillus_casei":"ATCC334","Oryzias_latipes":"ensembl64","Mycoplasma_hyopneumoniae":"J","Chlorocebus_aethiops":"Newbler_1.0.2.3","Plasmodium_falciparum":"3D7_Oct11","Salmonella_pullorum":"449_87","PhiX":"Illumina","Mycobacterium_avium":"paratuberculosis_K-10","Norwalk_virus":"Norovirus_Hu_GII.4_HS194_2009_US","Human_herpesvirus_7":"RK","Salmonella_bongori":"12149","Pseudomonas_fluorescens":"Pf0-1","Staphylococcus_aureus":"NCTC_8325","Yersinia_pseudotuberculosis":"IP_31758","Echinococcus_granulosus":"20110714","Acinetobacter_baumannii":"MDR-ZJ06","Human_herpesvirus_3":"Dumas","Shigella_flexneri":"2a_2457T","Bordetella_pertussis":"Tohama_I","Danio_rerio":"zv9","Escherichia_coli":"K12","Influenza_A":"H1N1","Streptococcus_agalactiae":"NEM316","Staphylococcus_saprophyticus":"ATCC_15305","Campylobacter_fetus":"subsp_fetus_82-40","Hepatitis_C_virus":"subtype_1a","Monodelphis_domestica":"GCA_000002295.1","Lambda":"NEB3011","Streptomyces_venezuelae":"ATCC_10712","Proteus_mirabilis":"HI4320","Echinococcus_multilocularis":"20100601","Streptococcus_equi":"4047","Heterocephalus_glaber":"GCA_000247695.1","Burkholderia_gladioli":"BSR3","Caenorhabditis_elegans":"101019",
"Haemophilus_influenzae":"Rd_KW20","Chlamydia_trachomatis":"L2b_UCH-1_proctitis","Onchocerca_volvulus":"OvD2P9_sspace3kb_200212","Schizosaccharomyces_pombe":"972h-","Neisseria_meningitidis":"MC58","Campylobacter_jejuni":"NCTC11168","Burkholderia_cenocepacia":"J2315","Leishmania_infantum":"JPCM5","Human_herpesvirus_2":"HG52","Wolbachia_endosymbiont_of_Drosophila_melanogaster":"ASM802v1",
"Betacoronavirus":"Human_coronavirus_HKU1","Staphylococcus_haemolyticus":"JCSC1435","Homo_sapiens":"1000Genomes","Clostridium_difficile":"Strain_630","Citrobacter_rodentium":"ICC168","Streptococcus_dysgalactiae":"GGS_124","Neisseria_gonorrhoeae":"FA_1090","Propionibacterium_acnes":"KPA171202","Dracunculus_medinensis":"v.1.0.1","Streptococcus_suis":"BM407","Plasmodium_vivax":"ASM241v2","Salmonella_enterica":"Typhimurium_LT2","Mycobacterium_tuberculosis":"H37Rv","Human_herpesvirus_4":"Wild_type","Anopheles_gambiae":"PEST","Leishmania_donovani":"V1_Un","Canis_familiaris":"UCSC_BROAD2","Brugia_pahangi":"Brugia_pahangi_v0.04_IMG","Actinobacillus_pleuropneumoniae":"L20","Sarcophilus_harrisii":"sc-v5.0","Shigella_sonnei":"Ss046","Brugia_malayi":"AAQA01000000","Schistosoma_mansoni":"./ASM23792v1","Myotis_lucifugus":"GCA_000147115.1","HIV_1":"Human_immunodeficiency_virus_1","Plasmodium_chabaudi":"chabaudi","Mus_musculus":"GRCm38"},"tag_index":"93",
"aligned_read_count":{"Bacillus_thuringiensis":"0","Human_herpesvirus_8":"0","Vibrio_cholerae":"0","Drosophila_melanogaster":"33","Streptococcus_pyogenes":"0","Gorilla_gorilla":"9161","Saccharomyces_cerevisiae":"5","Chlamydophila_abortus":"0","Streptococcus_uberis":"0","Mycobacterium_abscessus":"0","Trypanosoma_brucei":"6","Giardia_intestinalis":"0","Plasmodium_berghei":"5","Strongyloides_ratti":"9","Melissococcus_plutonius":"0","Tupaia_belangeri":"1030","Tursiops_truncatus":"1320","Aspergillus_fumigatus":"5","Streptococcus_pneumoniae":"0","Shigella_boydii":"0","Human_herpesvirus_1":"0","Mycobacterium_bovis":"0","Rhesus_macaque":"6370","Human_herpesvirus_5":"0",
"Haemophilus_parasuis":"0","Pseudomonas_aeruginosa":"1","Yersinia_enterocolitica":"0","Leishmania_major":"6","Burkholderia_pseudomallei":"0","Bordetella_bronchiseptica":"0",
"Human_herpesvirus_6":"0","Trichuris_muris":"20","Xenopus_tropicalis":"128","Leptospira_interrogans":"2","Plasmodium_knowlesi":"9","Hymenolepis_microstoma":"6","Streptomyces_coelicolor":"0","Klebsiella_pneumoniae":"0","Serratia_proteamaculans":"0","Cryptosporidium_parvum":"6","Sus_scrofa":"1035","Lactobacillus_casei":"0","Oryzias_latipes":"31","Mycoplasma_hyopneumoniae":"2","Chlorocebus_aethiops":"6653","Plasmodium_falciparum":"8","Salmonella_pullorum":"0","PhiX":"0","Mycobacterium_avium":"0","Norwalk_virus":"0","Human_herpesvirus_7":"0","Salmonella_bongori":"0","Pseudomonas_fluorescens":"0","Staphylococcus_aureus":"0","Yersinia_pseudotuberculosis":"0","Echinococcus_granulosus":"9","Acinetobacter_baumannii":"0","Human_herpesvirus_3":"0","Shigella_flexneri":"1","Bordetella_pertussis":"0","Danio_rerio":"52","Escherichia_coli":"0","Influenza_A":"0","Streptococcus_agalactiae":"0","Staphylococcus_saprophyticus":"0","Campylobacter_fetus":"0","Monodelphis_domestica":"227","Hepatitis_C_virus":"2","Lambda":"0","Streptomyces_venezuelae":"0","Proteus_mirabilis":"0","Heterocephalus_glaber":"1077","Echinococcus_multilocularis":"7","Streptococcus_equi":"0","Burkholderia_gladioli":"0","Caenorhabditis_elegans":"7",
"Haemophilus_influenzae":"0","Chlamydia_trachomatis":"0","Onchocerca_volvulus":"77","Schizosaccharomyces_pombe":"5","Neisseria_meningitidis":"1","Campylobacter_jejuni":"0","Burkholderia_cenocepacia":"0","Leishmania_infantum":"3","Human_herpesvirus_2":"0","Wolbachia_endosymbiont_of_Drosophila_melanogaster":"0","Betacoronavirus":"0","Staphylococcus_haemolyticus":"0","Homo_sapiens":"9875","Clostridium_difficile":"0","Citrobacter_rodentium":"0","Streptococcus_dysgalactiae":"0","Neisseria_gonorrhoeae":"0","Dracunculus_medinensis":"15","Propionibacterium_acnes":"0","Plasmodium_vivax":"9","Streptococcus_suis":"0","Salmonella_enterica":"0","Mycobacterium_tuberculosis":"0","Human_herpesvirus_4":"0","Anopheles_gambiae":"13","Leishmania_donovani":"7","Canis_familiaris":"1243","Brugia_pahangi":"14","Actinobacillus_pleuropneumoniae":"0","Sarcophilus_harrisii":"236","Shigella_sonnei":"0","Myotis_lucifugus":"1096","Brugia_malayi":"17","Schistosoma_mansoni":"5","HIV_1":"0","Mus_musculus":"640","Plasmodium_chabaudi":"5"},
  "aligner_version":"0.12.1"}
};

my $values = from_json($json);
my $rs = $schema->resultset('RefMatch');
isa_ok($rs->new_result($values), 'npg_qc::Schema::Result::RefMatch');

{
  my %values1 = %{$values};
  my $v1 = \%values1;

  $rs->deflate_unique_key_components($v1);
  is($v1->{'tag_index'}, 93, 'tag index not deflated');
  lives_ok {$rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()} 'tag record inserted';
  my $rs1 = $rs->search({});
  is ($rs1->count, 1, q[one row created in the table]);
  my $row = $rs1->next;
  is($row->tag_index, 93, 'tag index retrieved correctly');
  is(ref $row->aligned_read_count, 'HASH', 'aligned_read_count returned as hash ref');
  cmp_deeply($row->aligned_read_count, $values->{'aligned_read_count'},
    'aligned_read_count hash content is correct'); 
}

1;
