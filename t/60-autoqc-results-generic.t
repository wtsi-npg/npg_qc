use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;

use npg_tracking::glossary::composition;
use npg_tracking::glossary::composition::component::illumina;

use_ok ('npg_qc::autoqc::results::generic');

my $c = npg_tracking::glossary::composition->new(
  components => [
    npg_tracking::glossary::composition::component::illumina->new(
      id_run => 3, position => 1, tag_index => 4)
  ]);

subtest 'simple attributes and methods' => sub {
  plan tests => 15;

  my $r = npg_qc::autoqc::results::generic->new(
              composition  => $c
  );
  isa_ok ($r, 'npg_qc::autoqc::results::generic');
  is ($r->pp_name(), undef, 'descriptor is undefined');
  is ($r->doc(), undef, 'doc is undefined');
  is ($r->filename_root, '3_1#4.unknown', 'file name root');
  is ($r->class_name, 'generic', 'class name');
  is ($r->check_name, 'generic unknown', 'check name');
  $r->doc({}); # Can always be expected to be set
  is_deeply ($r->massage_for_render, {}, 'No doc, no data for render');

  $r = npg_qc::autoqc::results::generic->new(
              composition => $c,
              pp_name     => 'pp1',
              doc         => {qc_pass => 'TRUE', num_aligned_reads => 3},
  );
  isa_ok ($r, 'npg_qc::autoqc::results::generic');
  is ($r->pp_name(), 'pp1', 'descriptor');
  is_deeply ($r->doc(), {qc_pass => 'TRUE', num_aligned_reads => 3},
    'metrics hash');
  is ($r->filename_root, '3_1#4.pp1', 'file name root');
  is ($r->class_name, 'generic', 'class name');
  is ($r->check_name, 'generic pp1', 'check name');

  $r->doc({
    'QC summary' => {
      rubbish => 'unseen',
      num_aligned_reads => 2,
      qc_pass => 'TRUE',
      pct_covered_bases => 100
    },
    meta => {
      sample_type => 'positive_control',
      num_input_reads => 4,
      max_negative_control_filtered_read_count => 999,
      min_artic_passed_filtered_read_count => ''
    }
  });

  is_deeply(
    $r->massage_for_render,
    {
      num_aligned_reads => 2,
      num_input_reads => 8,
      control_type => 'positive',
      longest_no_N_run => '',
      pct_N_bases => '',
      pct_covered_bases => 100,
      qc_pass => 'TRUE',
      max_negative_control_filtered_read_count => 999,
      min_artic_passed_filtered_read_count => ''
    },
    'Formatting positive control with extra keys'
  );

  $r->doc({
    meta => {
      sample_type => 'negative_control',
      num_input_reads => 4,
    }
  });

  is_deeply(
    $r->massage_for_render,
    {
      num_input_reads => 8,
      control_type => 'negative',
      max_negative_control_filtered_read_count => '',
      min_artic_passed_filtered_read_count => ''
    },
    'Formatting negative control with no QC summary'
  );
};

subtest 'setting info' => sub {
  plan tests => 14;

  my $r = npg_qc::autoqc::results::generic->new(
          composition  => $c
  );
  is ($r->pp_name(), undef, 'descriptor is undefined');
  is ($r->info->{Pipeline_name}, undef, 'pipeline name is undefined');
  is ($r->info->{Pipeline_version}, undef, 'pipeline version is undefined');
  $r->set_pp_info('pp1', 'v.0.1');
  is ($r->pp_name(), 'pp1', 'descriptor available');
  is ($r->check_name, 'generic pp1', 'check name');
  is ($r->info->{Pipeline_name}, 'pp1', 'pipeline name');
  is ($r->info->{Pipeline_version}, 'v.0.1', 'pipeline version');

  $r = npg_qc::autoqc::results::generic->new(
       composition => $c,
       pp_name     => 'pp1',
       doc         => {qc_pass => 'TRUE', num_aligned_reads => 3}
  );
  is ($r->pp_name(), 'pp1', 'descriptor');
  is ($r->info->{Pipeline_name}, undef, 'pipeline name is undefined');
  is ($r->info->{Pipeline_version}, undef, 'pipeline version is undefined');
  throws_ok { $r->set_pp_info('pp2', 'v.0.1') }
    qr/Cannot reset portable pipeline name/,
    'pipeline name cannot be reset';
  $r->set_pp_info('pp1', 'v.0.1');
  is ($r->pp_name(), 'pp1', 'descriptor available');
  is ($r->info->{Pipeline_name}, 'pp1', 'pipeline name');
  is ($r->info->{Pipeline_version}, 'v.0.1', 'pipeline version');
};

1;
