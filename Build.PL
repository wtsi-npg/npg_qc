use strict;
use warnings;
use npg_tracking::util::build;

my $class = npg_tracking::util::build->subclass(code => <<'EOF');
  use strict;
  use warnings;
  use File::Path qw(make_path remove_tree);
  use File::Which qw(which);
  use npg_tracking::util::abs_path qw(abs_path);
  use File::Basename;

  my $C_SOURCE_DIR = q[src];

  my $c_tools = {
    'norm_fit' => {
      'copy'     => [qw/norm_fit/],
                  },
    'gt_utils' => {
      'copy'     => [qw/find_gt_match gt_pack/],
                  },
  };

  if (which('lsb_release') and `lsb_release -a` =~ /precise/ismx) {
    $c_tools->{'fastq_summ'} = {'copy'     => [qw/fastq_summ/],
                                'samtools' => 1};
  }

  sub _c_build_dir {
    return join(q[/], $C_SOURCE_DIR, shift, 'build');
  }

  sub _c_src_dir {
    return join(q[/], $C_SOURCE_DIR, shift);
  }

  sub _samtools_option {
    my $self = shift;

    my ($samtools, $htslib);

    # Requires the samtools source code to build
    if ($ENV{SAMTOOLS_SOURCE_PATH}) {
      $samtools = $ENV{SAMTOOLS_SOURCE_PATH};
    } else {
      $samtools = _relative_to_bin('samtools')
    }

    if ($ENV{HTSLIB_INSTALL_PATH}) {
      $htslib = $ENV{HTSLIB_INSTALL_PATH};
    } else {
      $htslib = _relative_to_bin('htsfile')
    }

    my @pkgs;
    if ($samtools && $htslib) {
      push @pkgs, "SAMTOOLS_LOC=$samtools";
      push @pkgs, "HTSLIB_LOC=$htslib";

      if ($self->verbose) {
        warn "Found samtools source $samtools\n";
        warn "Found htslib installed $htslib\n";
      }
    }

    return \@pkgs;
  }

  sub _relative_to_bin {
    my ($executable) = @_;

    my $path;
    my @found = which($executable);
    if (@found) {
      $path = dirname abs_path($found[0]);
      if ($path =~ m{/bin\Z}smx) {
        $path = dirname $path;
      }
    }

    return $path;
  }

  sub ACTION_build {
    my $self = shift;
    $self->SUPER::ACTION_build;

    # Build C executables
    foreach my $tool ( keys %{$c_tools} ) {
      if ($self->verbose) {
        warn "Building $tool\n";
      }
      my $bdir = _c_build_dir($tool);
      make_path $bdir;
      my $silent = $self->verbose ? q[] : '--silent';
      my $extra_info = q[];
 
      if ($c_tools->{$tool}->{'samtools'}) {
        my @pkgs = @{$self->_samtools_option()};
        if (!@pkgs) {
          warn 'samtools and htslib locations not declared or detected, ' .
                 "skipping $tool build\n";
          next;
        }
        $extra_info = join q[ ], @pkgs;
      }

      my $command = sprintf 'make %s --directory %s %s',
                      $silent, _c_src_dir($tool), $extra_info;
      if (system $command) {
        die "Failed to compile $tool";
      }
      foreach my $ename ( @{$c_tools->{$tool}->{'copy'}} ) {
        $self->copy_if_modified(
          from    => join(q[/], $bdir, $ename),
          to_dir  => join(q[/], $self->base_dir(), $self->blib(), 'script'),
          flatten => 1);
      }
    }

    # Build R script
    $self->copy_if_modified(
      from    => 'lib/R/gc_bias_data.R',
      to_dir  => join(q[/], $self->base_dir(), $self->blib()),
      flatten => 0);
  }

  sub ACTION_clean {
    my $self = shift;
    $self->SUPER::ACTION_clean;

    foreach my $tool ( keys %{$c_tools} ) {
      if ($self->verbose) {
        warn "Cleaning $tool\n";
      }
      my $silent = $self->verbose ? q[] : '--silent';
      system "make clean $silent --directory " . _c_src_dir($tool);
      remove_tree _c_build_dir($tool);
    }
  }
EOF

my $requires = {
                'autodie'                         => 0,
                'base'                            => 0,
                'Carp'                            => 0,
                'Class::Load'                     => 0,
                'ClearPress'                      => 0,
                'Compress::Zlib'                  => 0,
                'Cwd'                             => 0,
                'DBI'                             => 0,
                'DBIx::Class'                     => 0,
                'DBIx::Class::InflateColumn::Serializer' => 0,
                'Data::Dumper'                    => 0,
                'DateTime'                        => 0,
                'DateTime::Format::MySQL'         => 0,
                'Digest::MD5'                     => 0,
                'Digest::SHA1'                    => 0,
                'Exporter'                        => 0,
                'English'                         => 0,
                'Fatal'                           => 0,
                'Fcntl'                           => 0,
                'File::Basename'                  => 0,
                'File::Glob'                      => 0,
                'File::Path'                      => 0, 
                'File::Spec'                      => 0,
                'File::Spec::Functions'           => 0,
                'File::Slurp'                     => 0,
                'File::Temp'                      => 0,
                'FindBin'                         => '1.47',
                'Getopt::Long'                    => '2.37',
                'Getopt::Std'                     => 0,           
                'HTTP::Request'                   => 0,          
                'IPC::SysV'                       => 0,
                'IO::Compress::Xz'                => '2.068',
                'IO::Uncompress::UnXz'            => '2.068',
                'JSON'                            => '2.12',
                'JSON::XS'                        => 0,
                'lib'                             => 0,            
                'List::MoreUtils'                 => 0,
                'List::Util'                      => 0,
                'LWP::UserAgent'                  => 0,
                'Math::Round'                     => 0,
                'MIME::Base64'                    => 0,
                'MIME::Base64::Perl'              => 0,
                'Module::Pluggable::Object'       => 0,
                'Moose'                           => 0,
                'Moose::Meta::Class'              => 0,
                'Moose::Role'                     => 0,
                'Moose::Util::TypeConstraints'    => 0,
                'MooseX::AttributeCloner'         => 0,
                'MooseX::AttributeHelpers'        => 0,
                'MooseX::ClassAttribute'          => 0,
                'MooseX::Getopt'                  => 0,
                'MooseX::NonMoose'                => 0,
                'MooseX::Storage'                 => 0,
                'MooseX::StrictConstructor'       => 0,
                'namespace::autoclean'            => 0,
                'Parallel::ForkManager'           => 0,
                'PDL::Core'                       => 0,
                'PDL::Lite'                       => 0,
                'PDL::Primitive'                  => 0,
                'Perl6::Slurp'                    => 0,
                'Pod::Usage'                      => 0,
                'POSIX'                           => 0,
                'Readonly'                        => 0,
                'Readonly::XS'                    => 0,
                'Statistics::Lite'                => 0,
                'strict'                          => 0,
                'Try::Tiny'                       => 0,
                'warnings'                        => 0,
                'URI::Escape'                     => 0,
                'XML::LibXML'                     => 0,

                'npg_common::Alignment'                    => 0,
                'npg_common::extractor::fastq'             => 0,
                'npg_common::fastqcheck'                   => 0,
                'npg_common::roles::software_location'     => 0,
                'npg_common::sequence::reference::base_count'  => 0,
                'npg_testing::db'                          => 0,
                'npg_tracking::data::reference::list'      => 0,
                'npg_tracking::data::bait::find'           => 0,
                'npg_tracking::data::snv::find'            => 0,
                'npg_tracking::glossary::composition'      => 0,
                'npg_tracking::glossary::composition::factory' => 0,
                'npg_tracking::glossary::composition::factory::attributes' => 0,
                'npg_tracking::glossary::composition::component'           => 0,
                'npg_tracking::glossary::composition::component::illumina' => 0,
                'npg_tracking::glossary::composition::factory::rpt_list'   => 0,
                'npg_tracking::glossary::rpt'              => 0,
                'npg_tracking::glossary::run'              => 0,
                'npg_tracking::glossary::lane'             => 0,
                'npg_tracking::glossary::subset'           => 0,
                'npg_tracking::glossary::tag'              => 0,
                'npg_tracking::illumina::run::folder'      => 0,
                'npg_tracking::illumina::run::short_info'  => 0,
                'npg_tracking::illumina::run::long_info'   => 0,
                'npg_tracking::Schema'                     => 0,
                'npg_tracking::util::abs_path'             => 0,
                'npg_tracking::util::types'                => 0,
                'npg::util'                                => 0,
                'st::api::base'                            => 0,
                'st::api::lims'                            => 0,
                'WTSI::DNAP::Warehouse::Schema'            => 0,
                'WTSI::NPG::iRODS'                         => 0,
                'WTSI::NPG::iRODS::DataObject'             => 0
};

my $build_requires = {

                'Archive::Extract'                => 0,
                'Cwd'                             => 0,
                'DateTime::Format::SQLite'        => 0,
                'DBD::SQLite'                     => 0,
                'ExtUtils::CBuilder'              => 0,
                'File::Copy'                      => 0,
                'Test::Deep'                      => 0,
                'Test::Distribution'              => 0,
                'Test::Perl::Critic'              => 0,
                'Test::Warn'                      => 0,
                'Test::Exception'                 => 0,
                'Test::More'                      => 0,
                'npg_testing::db'                 => 0
};

my $builder = $class->new(

                'module_name'         => 'npg_qc',
                'dist_author'         => q(npg <npg@sanger.ac.uk>),
                'dist_version'        => $class->git_tag(),
                'dist_abstract'       => 'Illumina and WTSI quality control for Illumina sequencing data',
                'license'             => 'gpl',

          'configure_requires' => {
                'ExtUtils::CBuilder'              => 0,
                'npg_tracking::util::build'       => 0,
          },

          'build_requires' => $build_requires,
          'requires'      =>  $requires,

          'dist'          => { COMPRESS => 'gzip', SUFFIX => 'gz', },
         );

$builder->create_build_script();

1;
