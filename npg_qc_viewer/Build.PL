use strict;
use warnings;
use lib '../lib';
use npg_tracking::util::build;

my $class = npg_tracking::util::build->subclass(code => <<'EOC');

use Cwd 'abs_path';

  sub process_seqqc_files {
    my $self = shift;

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
   'dist_version'      => npg_tracking::util::build->git_tag(),
   'dist_abstract'     => q(SeqQC - viewer for autoqc analysis results),
   'license'           => 'gpl',
   'dist'              => { COMPRESS => 'gzip', SUFFIX => 'gz', },

   'requires'          => {
        'Carp'                                         => '0',
        'Catalyst::Runtime'                            => '5.90042',
        'Catalyst::Devel'                              => '0',
        'Catalyst::Plugin::ConfigLoader'               => '0',
        'Catalyst::Plugin::Static::Simple'             => '0',
        'Catalyst::Plugin::Authorization::Roles'       => '0',
        'Catalyst::Authentication::Store::DBIx::Class' => '0',
        'Catalyst::Action::RenderView'                 => '0',
        'Catalyst::Plugin::StackTrace'                 => '0',
        'Catalyst::Controller'                         => '0',
        'Catalyst::Controller::DBIC::API::RPC'         => '0',
        'Catalyst::Model'                              => '0',
        'Catalyst::Model::Adaptor'                     => '0',
        'Catalyst::Model::DBIC::Schema'                => '0',
        'Catalyst::Model::Adaptor'                     => '0',
        'Catalyst::View::TT'                           => '0',
        'Config::General'                              => '2.48',
        'DateTime'                                     => '0',
        'DateTime::Duration'                           => '0',
        'English'                                      => '0',
        'File::Slurp'                                  => '0',
        'FindBin'                                      => '0',
        'GD::Image'                                    => '0',
        'HTTP::Request'                                => '0',
        'JSON'                                         => '0',
        'LWP::UserAgent'                               => '0',
        'Math::Gradient'                               => '0',
        'Moose'                                        => '0',
        'Moose::Role'                                  => '0',
        'namespace::autoclean'                         => '0',
        'Readonly'                                     => '0',
        'strict'                                       => '0',
        'warnings'                                     => '0',

        'npg_common::fastqcheck'                       => '0',
        'npg_common::run::file_finder'                 => '0',
        'npg::authentication::sanger_sso'              => '0',
        'npg_tracking::Schema'                         => '0',
        'npg_tracking::daemon'                         => '0',
        'npg_warehouse::Schema'                        => '0',
        'npg_qc::Schema'                               => '0',
        'npg_qc::autoqc::qc_store'                     => '0',
        'npg_qc::autoqc::qc_store::options'            => '0',
        'npg_qc::autoqc::role::rpt_key'                => '0',
        'npg_qc::autoqc::results::collection'          => '0',
   },

   'build_requires'    => {
        'npg_tracking::util::build'                     => '0',
        'Catalyst::Test'                                => '0',
        'Catalyst::Authentication::Credential::Testing' => '0',
        'Cwd'                                           => '0',
        'DateTime'                                      => '0',
        'File::Temp'                                    => '0',
        'File::Spec'                                    => '0',
        'File::Spec::Functions'                         => '0',
        'GD'                                            => '0',
        'HTTP::Headers'                                 => '0',
        'HTTP::Request::Common'                         => '0',
        'Sys::Hostname'                                 => '0',
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
        'XML::LibXML'                                   => '1.70',
   },
);


$builder->add_build_element('seqqc');
if ($builder->install_base()) {
  $builder->install_path('seqqc' => join q[/], $builder->install_base(), 'seqqc');
}

$builder->create_build_script();

1;

