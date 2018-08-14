package npg_qc::illumina::loader;

use Moose;
use namespace::autoclean;
use Readonly;
use MooseX::Getopt;
use Module::Pluggable::Object;

extends 'npg_tracking::illumina::runfolder';

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::illumina::loader

=head1 SYNOPSIS

  npg_qc::illumina::loader->new(id_run => $iIdRun)->run();

=head1 DESCRIPTION

 Illumina analysis data loader 

=cut

Readonly::Array my @LOADER_MODULES => qw/ Cluster_Density /;

=head1 SUBROUTINES/METHODS

=head2 schema

create an ojbect of dbix class schema for QC database

=cut

has q{schema} => (isa           => q{npg_qc::Schema},
                  is            => q{ro},
                  lazy_build    => 1,
                 );
sub _build_schema {
  return npg_qc::Schema->connect();
}

=head2 schema_npg_tracking

create an ojbect of dbix class schema for run tracking database

=cut

has q{schema_npg_tracking} => (isa        => q{npg_tracking::Schema},
                               is         => q{ro},
                               lazy_build => 1,
                              );
sub _build_schema_npg_tracking {
  return npg_tracking::Schema->connect();
}

=head2 run

 Loads one run Illumina analysis statistics to a database

=cut

sub run {
  my $self = shift;

  Module::Pluggable::Object->new(
    require     => 1,
    search_path => __PACKAGE__,
    except      => [ __PACKAGE__ . q[::base] ]
                                )->plugins;

  $self->_mlog(q{Loading Illimina Analysis Data for Run } . $self->id_run() .
    q{ into QC database});

  foreach my $mod (@LOADER_MODULES) {
    my $m = join q[::], __PACKAGE__ , $mod;
    $self->_mlog(qq{***** Calling $m *****});
    $m->new(id_run              => $self->id_run(),
            runfolder_path      => $self->runfolder_path(),
            schema              => $self->schema,
            schema_npg_tracking => $self->schema_npg_tracking)->run();
  }

  $self->_mlog(q{All QC data loading finished for run }.$self->id_run());

  return;
}

sub _mlog {
  my ($self, $message) = @_;
  if ($message) {
    warn "$message\n";
  }
  return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Readonly

=item MooseX::Getopt

=item Module::Pluggable::Object

=item npg_tracking::illumina::runfolder

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=over

=item Andy Brown

=item Marina Gourtovaia

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 GRL

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
