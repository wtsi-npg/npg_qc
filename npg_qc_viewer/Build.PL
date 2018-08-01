use strict;
use warnings;
use lib '../lib';
use WTSI::DNAP::Utilities::Build;

my $class = WTSI::DNAP::Utilities::Build->subclass(code => <<'EOC');

  use Cwd qw/abs_path getcwd/;
  use File::Which qw(which);

  sub process_seqqc_files {
    my $self = shift;

    if ($self->args('installjsdeps')) {
      if (which('node') and which('npm')) {
        warn "Installing node dependencies\n";

        my $result_npm = system 'npm install';
        if ($result_npm) {
          die 'Fail to install node dependencies';
        }

        warn "Checking/fetching bower javascript dependencies\n";

        my $result = system '$(npm bin)/bower install --force-latest';
        if ($result) {
          die 'Fail to install bower javascript dependencies';
        }
      } else {
        warn "To install javascript dependencies, node should be on the path;\n";
        die 'Javascript dependencies cannot be installed';
      }
    }

    my $dest = 'blib/seqqc';
    if (!-e $dest) {
      mkdir $dest;
    }
    foreach my $file ( @{$self->rscan_dir('root')} ) {
      if (-f $file) {
        $self->copy_if_modified('from' => $file, 'to_dir' => $dest);
      }
    }
    $self->copy_if_modified('from' => 'npg_qc_viewer.conf', 'to_dir' => $dest);
    $self->copy_if_modified('from' => 'npg_qc_viewer.psgi', 'to_dir' => $dest);
    return;
  }

EOC

my $builder = $class->new(

   'module_name'       => 'SeqQC',
   'dist_author'       => q(wtsi-npg <npg@sanger.ac.uk>),
   'dist_version'      => WTSI::DNAP::Utilities::Build->git_tag(),
   'dist_abstract'     => q(SeqQC - viewer for autoqc analysis results),
   'license'           => 'gpl',
   'dist'              => { COMPRESS => 'gzip', SUFFIX => 'gz', },
   'get_options'       => {
     'installjsdeps' => { type => ''},
   },

   'requires'          => {
        'Carp'                                         => '0',
        'Catalyst'                                     => '0',
        'Catalyst::Runtime'                            => '5.90042',
        'Catalyst::Devel'                              => '0',
        'Catalyst::Plugin::ConfigLoader'               => '0',
        'Catalyst::Plugin::Static::Simple'             => '0',
        'Catalyst::Plugin::Authorization::Roles'       => '0',
        'Catalyst::Authentication::Store::DBIx::Class' => '0',
        'Catalyst::Action::RenderView'                 => '0',
        'Catalyst::Plugin::StackTrace'                 => '0',
        'Catalyst::Controller'                         => '0',
        'Catalyst::Controller::REST'                   => '0',
        'Catalyst::Model'                              => '0',
        'Catalyst::Model::Adaptor'                     => '0',
        'Catalyst::Model::DBIC::Schema'                => '0',
        'Catalyst::Model::Adaptor'                     => '0',
        'Catalyst::View::TT'                           => '0',
        'Cwd'                                          => '0',
        'English'                                      => '0',
        'File::Basename'                               => '0',
        'File::Slurp'                                  => '0',
        'File::Spec::Functions'                        => '0',
        'FindBin'                                      => '0',
        'Config::General'                              => '2.48',
        'English'                                      => '0',
        'GD::Image'                                    => '0',
        'HTTP::Request'                                => '0',
        'JSON'                                         => '0',
        'JSON::XS'                                     => '0',
        'LWP::UserAgent'                               => '0',
        'List::MoreUtils'                              => '0',
        'Math::Gradient'                               => '0',
        'Moose'                                        => '0',
        'Moose::Meta::Class'                           => '0',
        'Moose::Role'                                  => '0',
        'MooseX::StrictConstructor'                    => '0',
        'MooseX::Types::Moose'                         => '0',
        'namespace::autoclean'                         => '0',
        'Params::Validate'                             => '0',
        'Readonly'                                     => '0',
        'strict'                                       => '0',
        'Try::Tiny'                                    => '0',
        'warnings'                                     => '0',
        'URI::URL'                                     => '0',

        'npg_common::fastqcheck'                       => '0',
        'npg::authentication::sanger_sso'              => '0',
        'npg_tracking::Schema'                         => '0',
        'npg_tracking::daemon'                         => '0',
        'npg_tracking::util::types'                    => '0',
        'npg_tracking::glossary::composition::component::illumina' => '0',
        'npg_tracking::glossary::composition::factory::rpt' => '0',
        'npg_qc::Schema'                               => '0',
        'npg_qc::autoqc::qc_store'                     => '0',
        'npg_qc::autoqc::qc_store::options'            => '0',
        'npg_qc::autoqc::role::rpt_key'                => '0',
        'npg_qc::autoqc::results::collection'          => '0',
        'npg_qc::autoqc::checks::check'                => '0',
        'npg_qc::mqc::outcomes'                        => '0',
        'WTSI::DNAP::Warehouse::Schema'                => '0',
   },

   'configure_requires' => {
        'WTSI::DNAP::Utilities::Build'                 => 0,
   },

   'build_requires'    => {
        'npg_tracking::glossary::composition::factory'  => '0',
        'npg_tracking::glossary::rpt'                   => '0',
        'npg_qc::autoqc::db_loader'                     => '0',
        'Archive::Extract'                              => '0',
        'Catalyst::Test'                                => '0',
        'DateTime'                                      => '0',
        'File::Temp'                                    => '0',
        'File::Spec'                                    => '0',
        'HTTP::Headers'                                 => '0',
        'HTTP::Request::Common'                         => '0',
        'Template'                                      => '0',
        'Template::Plugin::Number::Format'              => '0',
        'Test::More'                                    => '0',
        'Test::Deep'                                    => '0',
        'Test::Exception'                               => '0',
        'Test::Pod'                                     => '0',
        'Test::Pod::Coverage'                           => '0',
        'Test::Perl::Critic'                            => '0',
        'Test::Distribution'                            => '0',
        'Test::MockObject'                              => '0',
        'Test::WWW::Mechanize::Catalyst'                => '0',
        'URI::Escape'                                   => '0',
        'XML::LibXML'                                   => '1.70',
   },
);


$builder->add_build_element('seqqc');
if ($builder->install_base()) {
  $builder->install_path('seqqc' => join q[/], $builder->install_base(), 'seqqc');
}

$builder->create_build_script();

1;
