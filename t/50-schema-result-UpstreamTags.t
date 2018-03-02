use strict;
use warnings;
use Test::More tests => 13;
use Test::Exception;
use Moose::Meta::Class;
use JSON;

use npg_testing::db;
use t::autoqc_util;

use_ok('npg_qc::Schema::Result::UpstreamTags');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

my $json = '
{"barcode_file":"/lustre/scratch109/srpipe/tag_sets/sanger168.tags","id_run":"12234","info":{"Check":"npg_qc::autoqc::checks::upstream_tags","Check_version":"17782"},"instrument_name":"MS6","instrument_slot":"X","path":"/nfs/sf49/ILorHSorMS_sf49/analysis/140222_MS6_12234_A_MS2045957-300V2/Data/Intensities/BAM_basecalls_20140223-102451/no_cal/archive","perfect_match_lane_reads":4938642,"position":"1","prev_runs":[{"downstream_tag_count":0,"id_run":"12234","new_tag_count":16,"perfect_match_reads":0,"run_in_progress_date":"2014-02-23 09:55:09","tag_lengths":["11"]},{"downstream_tag_count":1,"id_run":"12211","new_tag_count":25,"perfect_match_reads":322,"run_in_progress_date":"2014-02-22 01:25:31","tag_lengths":["8"]},{"downstream_tag_count":0,"id_run":"12200","new_tag_count":27,"perfect_match_reads":41,"run_in_progress_date":"2014-02-20 01:38:47","tag_lengths":["8"]},{"downstream_tag_count":2,"id_run":"12186","new_tag_count":0,"perfect_match_reads":0,"run_in_progress_date":"2014-02-17 13:46:07","tag_lengths":["5"]},{"downstream_tag_count":27,"id_run":"12178","new_tag_count":26,"perfect_match_reads":30,"run_in_progress_date":"2014-02-15 15:38:16","tag_lengths":["8"]}],"tag0_perfect_match_reads":2158868,"total_lane_reads":7728297,"total_tag0_reads":2510593,"unexpected_tags":[{"id_run":"","one_mismatch_matches":"13771","perfect_match_count":"2155457","tag_index":"168","tag_sequence":"ACAACGCA"},{"id_run":"","one_mismatch_matches":"5459","perfect_match_count":"2378","tag_index":"55","tag_sequence":"TTCGCACC"},{"id_run":"","one_mismatch_matches":"3216","perfect_match_count":"498","tag_index":"123","tag_sequence":"CTTCACAT"},{"id_run":"12211","one_mismatch_matches":"4510","perfect_match_count":"279","tag_index":"64","tag_sequence":"TCTCTTCA"},{"id_run":"","one_mismatch_matches":"62","perfect_match_count":"80","tag_index":"159","tag_sequence":"ACGCAATC"},{"id_run":"12211","one_mismatch_matches":"2058","perfect_match_count":"25","tag_index":"67","tag_sequence":"TACCACCA"},{"id_run":"12200","one_mismatch_matches":"187","perfect_match_count":"22","tag_index":"7","tag_sequence":"CAGATCTG"},{"id_run":"12200","one_mismatch_matches":"350","perfect_match_count":"14","tag_index":"8","tag_sequence":"ACTTGATG"},{"id_run":"","one_mismatch_matches":"122","perfect_match_count":"6","tag_index":"131","tag_sequence":"CTTGCTTC"},{"id_run":"","one_mismatch_matches":"553","perfect_match_count":"6","tag_index":"149","tag_sequence":"ACGTTCAT"},{"id_run":"","one_mismatch_matches":"561","perfect_match_count":"6","tag_index":"83","tag_sequence":"GCTCCTTG"},{"id_run":"","one_mismatch_matches":"114","perfect_match_count":"5","tag_index":"127","tag_sequence":"CTGTACGG"},{"id_run":"12178","one_mismatch_matches":"28","perfect_match_count":"5","tag_index":"35","tag_sequence":"TTGGTATG"},{"id_run":"12178","one_mismatch_matches":"50","perfect_match_count":"5","tag_index":"43","tag_sequence":"TCATTGAG"},{"id_run":"","one_mismatch_matches":"30","perfect_match_count":"4","tag_index":"162","tag_sequence":"AGAGGACC"},{"id_run":"","one_mismatch_matches":"174","perfect_match_count":"3","tag_index":"95","tag_sequence":"GATTCATC"},{"id_run":"12178","one_mismatch_matches":"67","perfect_match_count":"3","tag_index":"37","tag_sequence":"TACTTCGG"},{"id_run":"12211","one_mismatch_matches":"55","perfect_match_count":"3","tag_index":"61","tag_sequence":"TGCTGATA"},{"id_run":"","one_mismatch_matches":"142","perfect_match_count":"3","tag_index":"91","tag_sequence":"GACCTTAG"},{"id_run":"","one_mismatch_matches":"42","perfect_match_count":"3","tag_index":"105","tag_sequence":"GGAGTCTA"},{"id_run":"","one_mismatch_matches":"251","perfect_match_count":"2","tag_index":"135","tag_sequence":"CAACCTCC"},{"id_run":"","one_mismatch_matches":"70","perfect_match_count":"2","tag_index":"113","tag_sequence":"GCGTCGAA"},{"id_run":"","one_mismatch_matches":"252","perfect_match_count":"2","tag_index":"167","tag_sequence":"AACTGGCA"},{"id_run":"","one_mismatch_matches":"1133","perfect_match_count":"2","tag_index":"144","tag_sequence":"CCTGAGCA"},{"id_run":"","one_mismatch_matches":"242","perfect_match_count":"2","tag_index":"158","tag_sequence":"ATTCGGAG"},{"id_run":"","one_mismatch_matches":"839","perfect_match_count":"2","tag_index":"85","tag_sequence":"GAGGATGG"},{"id_run":"12211","one_mismatch_matches":"148","perfect_match_count":"1","tag_index":"71","tag_sequence":"GTGTCCTT"},{"id_run":"12200","one_mismatch_matches":"50","perfect_match_count":"1","tag_index":"16","tag_sequence":"TCCGTCTT"},{"id_run":"","one_mismatch_matches":"24","perfect_match_count":"1","tag_index":"109","tag_sequence":"GGCAAGCA"},{"id_run":"","one_mismatch_matches":"452","perfect_match_count":"1","tag_index":"89","tag_sequence":"GTGTGTCG"},{"id_run":"","one_mismatch_matches":"223","perfect_match_count":"1","tag_index":"129","tag_sequence":"CACTCGAG"},{"id_run":"12200","one_mismatch_matches":"224","perfect_match_count":"1","tag_index":"14","tag_sequence":"TCTCGGTT"},{"id_run":"12178","one_mismatch_matches":"62","perfect_match_count":"1","tag_index":"49","tag_sequence":"TGTCTATC"},{"id_run":"","one_mismatch_matches":"96","perfect_match_count":"1","tag_index":"140","tag_sequence":"CGTTACTA"},{"id_run":"","one_mismatch_matches":"23","perfect_match_count":"1","tag_index":"117","tag_sequence":"CCGTATCT"},{"id_run":"12211","one_mismatch_matches":"64","perfect_match_count":"1","tag_index":"63","tag_sequence":"TGTGAAGA"},{"id_run":"12211","one_mismatch_matches":"27","perfect_match_count":"1","tag_index":"70","tag_sequence":"GATCTCTT"},{"id_run":"12211","one_mismatch_matches":"110","perfect_match_count":"1","tag_index":"68","tag_sequence":"TGCGTGAA"},{"id_run":"12178","one_mismatch_matches":"26","perfect_match_count":"1","tag_index":"30","tag_sequence":"TGTGGTTG"},{"id_run":"","one_mismatch_matches":"130","perfect_match_count":"1","tag_index":"156","tag_sequence":"ACTGTTAG"},{"id_run":"","one_mismatch_matches":"135","perfect_match_count":"1","tag_index":"146","tag_sequence":"CGGAGGAA"},{"id_run":"12200","one_mismatch_matches":"31","perfect_match_count":"0","tag_index":"18","tag_sequence":"TTCTGTGT"},{"id_run":"","one_mismatch_matches":"177","perfect_match_count":"0","tag_index":"125","tag_sequence":"CATGAATG"},{"id_run":"","one_mismatch_matches":"35","perfect_match_count":"0","tag_index":"148","tag_sequence":"AGGCAGCT"},{"id_run":"12178","one_mismatch_matches":"37","perfect_match_count":"0","tag_index":"31","tag_sequence":"TAGTCTTG"},{"id_run":"12200","one_mismatch_matches":"122","perfect_match_count":"0","tag_index":"11","tag_sequence":"GGCTACAG"},{"id_run":"12178","one_mismatch_matches":"117","perfect_match_count":"0","tag_index":"29","tag_sequence":"TCCTCAAT"},{"id_run":"","one_mismatch_matches":"138","perfect_match_count":"0","tag_index":"114","tag_sequence":"CGTTCGGT"},{"id_run":"12211","one_mismatch_matches":"44","perfect_match_count":"0","tag_index":"60","tag_sequence":"TCATCCTA"},{"id_run":"","one_mismatch_matches":"368","perfect_match_count":"0","tag_index":"101","tag_sequence":"GGTTGGAC"},{"id_run":"12200","one_mismatch_matches":"105","perfect_match_count":"0","tag_index":"17","tag_sequence":"TGTACCTT"},{"id_run":"","one_mismatch_matches":"74","perfect_match_count":"0","tag_index":"147","tag_sequence":"AGGAGATT"},{"id_run":"","one_mismatch_matches":"103","perfect_match_count":"0","tag_index":"112","tag_sequence":"GCAGGTAA"},{"id_run":"12211","one_mismatch_matches":"63","perfect_match_count":"0","tag_index":"69","tag_sequence":"GGTGAGTT"},{"id_run":"","one_mismatch_matches":"33","perfect_match_count":"0","tag_index":"104","tag_sequence":"GTGCAGTA"},{"id_run":"","one_mismatch_matches":"48","perfect_match_count":"0","tag_index":"121","tag_sequence":"CCTAGTAT"},{"id_run":"","one_mismatch_matches":"58","perfect_match_count":"0","tag_index":"96","tag_sequence":"GTCTTGGC"},{"id_run":"","one_mismatch_matches":"28","perfect_match_count":"0","tag_index":"98","tag_sequence":"GATGGTCC"},{"id_run":"12200","one_mismatch_matches":"34","perfect_match_count":"0","tag_index":"26","tag_sequence":"TTCCTGCT"},{"id_run":"12211","one_mismatch_matches":"28","perfect_match_count":"0","tag_index":"74","tag_sequence":"GGTCGTGT"},{"id_run":"","one_mismatch_matches":"49","perfect_match_count":"0","tag_index":"92","tag_sequence":"GCCTGTTC"},{"id_run":"","one_mismatch_matches":"35","perfect_match_count":"0","tag_index":"142","tag_sequence":"CTCTCTCA"},{"id_run":"","one_mismatch_matches":"51","perfect_match_count":"0","tag_index":"133","tag_sequence":"CACATTGC"},{"id_run":"12178","one_mismatch_matches":"60","perfect_match_count":"0","tag_index":"45","tag_sequence":"TATGCCAG"},{"id_run":"","one_mismatch_matches":"232","perfect_match_count":"0","tag_index":"54","tag_sequence":"TGTTCTCC"},{"id_run":"","one_mismatch_matches":"145","perfect_match_count":"0","tag_index":"136","tag_sequence":"CAGCTGAC"},{"id_run":"","one_mismatch_matches":"146","perfect_match_count":"0","tag_index":"88","tag_sequence":"GATAGAGG"},{"id_run":"12200","one_mismatch_matches":"100","perfect_match_count":"0","tag_index":"25","tag_sequence":"TGCGATCT"},{"id_run":"12211","one_mismatch_matches":"60","perfect_match_count":"0","tag_index":"59","tag_sequence":"TAGAACAC"},{"id_run":"","one_mismatch_matches":"78","perfect_match_count":"0","tag_index":"150","tag_sequence":"AACGTGTG"},{"id_run":"","one_mismatch_matches":"225","perfect_match_count":"0","tag_index":"143","tag_sequence":"CGACTGCA"},{"id_run":"","one_mismatch_matches":"44","perfect_match_count":"0","tag_index":"132","tag_sequence":"CATAGGTC"}]}
';

my $values = from_json($json);
$values->{'id_seq_composition'} =
  t::autoqc_util::find_or_save_composition($schema,
    {id_run => 12234, position => 1});
my $rs = $schema->resultset('UpstreamTags');
isa_ok($rs->new_result($values), 'npg_qc::Schema::Result::UpstreamTags');

{
  my %values1 = %{$values};
  my $v1 = \%values1;
  lives_ok {$rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()} 'record inserted';
  my $rs1 = $rs->search({});
  is ($rs1->count, 1, q[one row created in the table]);
  my $row = $rs1->next;
  is(ref $row->unexpected_tags, 'ARRAY', 'unexpected_tags returned as an array');
  is_deeply($row->unexpected_tags, $values->{'unexpected_tags'},
    'unexpected_tags array content is correct');
  is_deeply($row->prev_runs, $values->{'prev_runs'},
    'prev_runs array content is correct');

  %values1 = %{$values};
  $v1 = \%values1;
  delete $v1->{'id_run'};
  delete $v1->{'position'};
  my $row1;
  lives_ok {$row1 = $rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()}
    'another or the same row?';
  is ($row->id_upstream_tags, $row1->id_upstream_tags, 'new row is not created');

  %values1 = %{$values};
  $v1 = \%values1;
  delete $v1->{'id_run'};
  delete $v1->{'position'};
  $v1->{'id_seq_composition'} =
  t::autoqc_util::find_or_save_composition($schema,
    {id_run => 9225, position => 1});
  lives_ok {$row1 = $rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()}
    'another row';
  isnt ($row->id_upstream_tags, $row1->id_upstream_tags, 'new row is created');
  is ($row1->id_run, undef, 'id run value is undefined');
  is ($row1->position, undef, 'position value is undefined');
} 
 
1;


