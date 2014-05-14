#!/usr/bin/env perl

use strict;
use warnings;
use DBIx::Class::Schema::Loader qw(make_schema_at);
use Config::Auto;
use lib qw/lib/;

use npg_qc::autoqc::autoqc;
use npg_qc::autoqc::role::result;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mxs; $r; };

my $path = join q[/], $ENV{'HOME'}, q[.npg], q[npg_qc-Schema];
my $config = Config::Auto::parse($path);
my $domain = $ENV{'dev'} || q[live];
if (defined $config->{$domain}) {
  $config = $config->{$domain};
}
my $dsn = sprintf 'dbi:mysql:host=%s;port=%s;dbname=%s',
  $config->{'dbhost'}, $config->{'dbport'}, $config->{'dbname'};

my $roles_map = {};
my $role_base = 'npg_qc::autoqc::role::';
my $generic_role = $role_base . 'result';
foreach my $check (@{npg_qc::autoqc::autoqc->checks_list}) {
  my ($result_name, $dbix_result_name ) = $generic_role->class_names($check);
  my @roles = qw/npg_qc::Schema::Flators/;
  my $rpackage = $role_base . $result_name;
  my $found = eval "require $rpackage";
  if ($found) {
    push @roles, $rpackage;
  } else {
    push @roles, $generic_role;
  }
  $roles_map->{$dbix_result_name} = \@roles;
}
$roles_map->{'Fastqcheck'} = ['npg_qc::Schema::Flators'];

make_schema_at(
    'npg_qc::Schema',
    {
        debug               => 0,
        dump_directory      => q[lib],
        naming              => q[current],
        skip_load_external  => 1,
        use_moose           => 1,
        preserve_case       => 1,
        filter_generated_code => sub {
          my ($type, $class, $text) = @_;
          my $code = $text;
          $code =~ s/use\ utf8;//;
          if ($type eq 'result') {
            $code =~ tr/"/'/;
            $code =~ s/=head1\ NAME/\#\#no\ critic\(RequirePodAtEnd\ RequirePodLinksIncludeText\ ProhibitMagicNumbers\ ProhibitEmptyQuotes\)\n\n=head1\ NAME/;
          }
          return $code;
        },
        moniker_map         => {
          'alignment_filter_metrics'       => q[AlignmentFilterMetrics],
          'bam_flagstats'                  => q[BamFlagstats],
          'gc_bias'                        => q[GcBias],
          'pulldown_metrics'               => q[PulldownMetrics],
          'split_stats'                    => q[SplitStats],
          'split_stats_coverage'           => q[SplitStatsCoverage],
          'qx_yield'                       => q[QXYield],
          'tag_metrics'                    => q[TagMetrics],
          'tags_reporters'                 => q[TagsReporters],
          'upstream_tags'                  => q[UpstreamTags],
          'tag_decode_stats'               => q[TagDecodeStats],
          'errors_by_cycle'                => q[ErrorsByCycle],
          'errors_by_nucleotide'           => q[ErrorsByNucleotide],
          'errors_by_cycle_and_nucleotide' => q[ErrorsByCycleAndNucleotide],
          'cumulative_errors_by_cycle'     => q[CumulativeErrorsByCycle]
        },
	result_roles_map   => $roles_map,
 
        components=>[qw(InflateColumn::DateTime InflateColumn::Serializer)],
    },
    [$dsn, $config->{'dbuser'}, $config->{'dbpass'}]
);

1;
