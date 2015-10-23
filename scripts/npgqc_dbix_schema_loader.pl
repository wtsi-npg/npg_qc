#!/usr/bin/env perl

use strict;
use warnings;
use DBIx::Class::Schema::Loader qw(make_schema_at);
use Config::Auto;
use lib qw/lib/;

use npg_qc::autoqc::autoqc;
use npg_qc::autoqc::role::result;

our $VERSION = '0';

my $path = join q[/], $ENV{'HOME'}, q[.npg], q[npg_qc-Schema];
my $config = Config::Auto::parse($path);
my $domain = $ENV{'dev'} || q[live];
if (defined $config->{$domain}) {
  $config = $config->{$domain};
}
my $dsn = sprintf 'dbi:mysql:host=%s;port=%s;dbname=%s',
  $config->{'dbhost'}, $config->{'dbport'}, $config->{'dbname'};

my $roles_map = {};
my $components_map = {};
my $role_base = 'npg_qc::autoqc::role::';
my $generic_role = $role_base . 'result';
my $component = 'InflateColumn::Serializer';
my $flator = 'npg_qc::Schema::Flators';

foreach my $check (@{npg_qc::autoqc::autoqc->checks_list}) {
  my ($result_name, $dbix_result_name ) = $generic_role->class_names($check);
  
  my @roles = ($flator);
  my $rpackage = $role_base . $result_name;
  my $found = eval "require $rpackage";
  if ($found) {
    push @roles, $rpackage;
  } else {
    push @roles, $generic_role;
  }
  $roles_map->{$dbix_result_name}      = \@roles;
  $components_map->{$dbix_result_name} = [$component]
}
$roles_map->{'Fastqcheck'}      = [$flator];
$components_map->{'Fastqcheck'} = [$component];

make_schema_at(
    'npg_qc::Schema',
    {
        debug               => 0,
        dump_directory      => q[lib],
        naming              => { 
            relationships    => 'current', 
            monikers         => 'current', 
            column_accessors => 'preserve',
        },
        skip_load_external  => 1,
        use_moose           => 1,
        preserve_case       => 1,
        use_namespaces      => 1,
        default_resultset_class => 'ResultSet',

        rel_name_map        => sub {#Rename the id relationship so we can access flat versions of the objects and not only the whole trees from ORM.
          my %h = %{shift@_};
          my $name=$h{name};
          $name=~s/^id_//;
          return $name;
        },

        filter_generated_code => sub {
          my ($type, $class, $text) = @_;
          my $code = $text;
          $code =~ s/use\ utf8;//;
          $code =~ tr/"/'/;
          if ($type eq 'result') {
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
          'cumulative_errors_by_cycle'     => q[CumulativeErrorsByCycle],
          'samtools_stats'                 => q[SamtoolsStats],
        },

        result_roles_map   => $roles_map,

        components => [qw(InflateColumn::DateTime)],

        result_components_map => $components_map,

        additional_classes => (qw[namespace::autoclean],),
    },
    [$dsn, $config->{'dbuser'}, $config->{'dbpass'}]
);

1;
