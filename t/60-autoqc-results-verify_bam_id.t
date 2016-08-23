use strict;
use warnings;
use Test::More tests => 5;
use Test::Deep;
use Test::Exception;
use English qw(-no_match_vars);
use Carp;

use_ok('npg_qc::autoqc::results::verify_bam_id');

my $r = npg_qc::autoqc::results::verify_bam_id->new(
	id_run   => 12,
  position => 3,
  path     => q[mypath]
);

subtest q[Object type] => sub {
  plan tests => 3;
  isa_ok ( $r, 'npg_qc::autoqc::results::verify_bam_id' );
  is( $r->check_name(), 'verify bam id', 'Check name' );
  is( $r->class_name(), 'verify_bam_id', 'Class name' );
};

subtest q[Default criterion] => sub {
	plan tests => 1;
  is( $r->criterion, q[snps > 10000, average depth >= 4 and freemix < 0.05],
  	  q[default criterion] );
};

subtest q[Criterion from info] => sub {
  plan tests=> 3;
  my $r_from_json;
  my $json_path = q[t/data/autoqc/verify_bam_id/20000_1#2.verify_bam_id.json];
  lives_ok{ $r_from_json = npg_qc::autoqc::results::verify_bam_id->load($json_path); }
            q[Loaded from json];
  isa_ok ( $r_from_json, 'npg_qc::autoqc::results::verify_bam_id' );
  is( $r_from_json->criterion, q[snps > 10000, average depth >= 2 and freemix < 0.05],
  	  q[Criterion from json] );
};

subtest q[Criterion from default, old versions] => sub {
  plan tests=> 3;
  my $r_from_json;
  my $json_path = q[t/data/autoqc/verify_bam_id/19999_2#1.verify_bam_id.json];
  lives_ok{ $r_from_json = npg_qc::autoqc::results::verify_bam_id->load($json_path); }
            q[Loaded from json];
  isa_ok ( $r_from_json, 'npg_qc::autoqc::results::verify_bam_id' );
  is( $r_from_json->criterion, q[snps > 10000, average depth >= 4 and freemix < 0.05],
      q[Criterion from default] );
};

1;