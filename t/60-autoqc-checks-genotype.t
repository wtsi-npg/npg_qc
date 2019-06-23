use strict;
use warnings;
use Cwd;
use File::Temp qw/ tempdir /;
use Test::More tests => 10;
use Test::Exception;
use WTSI::NPG::iRODS;

use_ok ('npg_qc::autoqc::checks::genotype');

my $dir = tempdir(CLEANUP => 1);
my $pid = $$;
my $collection_name = "GenotypeTest.$pid";

my $have_irods_execs = exist_irods_executables();
my $env_file = $ENV{'WTSI_NPG_iRODS_Test_IRODS_ENVIRONMENT_FILE'} || q[];
local $ENV{'IRODS_ENVIRONMENT_FILE'} = $env_file || 'DUMMY_VALUE';

my $irods_tmp_coll;
my $irods;
if ($env_file && $have_irods_execs) {
  $irods = WTSI::NPG::iRODS->new(strict_baton_version => 0);
  $irods_tmp_coll = $irods->add_collection("GenotypeTest.$pid") ;
}

sub exist_irods_executables {
  return 0 unless `which ienv`;
  return 0 unless `which imkdir`;
  return 1;
}

END {
  # remove temporary iRODS collection
  if($irods_tmp_coll) {
    local $ENV{'IRODS_ENVIRONMENT_FILE'} = $env_file;
    eval {system("irm -r $collection_name")};
  }
}

SKIP: {
  skip 'iRODS not available', 9 unless $irods_tmp_coll;

  my $ref_repos = cwd . '/t/data/autoqc';
  my $expected_md5 = q[a4790111996a3f1c0247d65f4998e492];

  my $st = join q[/], $dir, q[samtools];
  `touch $st`;
  `chmod +x $st`;
  my $bt = join q[/], $dir, q[bcftools];
  `touch $bt`;
  `chmod +x $bt`;
  local $ENV{PATH} = join q[:], $dir, $ENV{PATH};
  my $data_dir = $dir."/data";
  mkdir($data_dir);
  `cp t/data/autoqc/alignment.bam $data_dir/2_1.bam`;
  `echo -n $expected_md5 > $data_dir/2_1.bam.md5`;

  # populate a temporary iRODS collection
  $irods->put_collection($data_dir, $irods_tmp_coll);
  my $irods_data_coll = $irods_tmp_coll."/data";

  my $r = npg_qc::autoqc::checks::genotype->new(
        irods       => $irods,
        id_run      => 2,
        position    => 1,
        input_files => ["$data_dir/2_1.bam"],
        repository  => $ref_repos,
  );
  isa_ok ($r, 'npg_qc::autoqc::checks::genotype');
  lives_ok { $r->result; } 'No error creating result object';
  lives_ok {$r->samtools } 'No error calling "samtools" accessor';
  is($r->samtools, $st, 'correct samtools path');
  lives_ok {$r->bcftools } 'No error calling "bcftools" accessor';
  is($r->bcftools, $bt, 'correct bcftools path');
  is($r->input_files_md5, $expected_md5,
    "Local MD5 string matches expected value");

  lives_ok {npg_qc::autoqc::checks::genotype->new(
    repository => $ref_repos, rpt_list => '2:1', path => q[t]); }
    'object via the rpt_list';

  my $irods_path = 'irods:'.$irods_data_coll.'/2_1.bam';
  $r = npg_qc::autoqc::checks::genotype->new(
    irods       => $irods,
    id_run      => 2,
    position    => 1,
    input_files => [$irods_path],
    repository  => $ref_repos,
  );
  is($r->input_files_md5, $expected_md5,
    "iRODS MD5 string matches expected value") or
    diag `ils -L $irods_data_coll/2_1.bam`
}

1;

