package npg_qc::report::common;

use Moose;
use namespace::autoclean;
use Readonly;
use Carp;

use npg_qc::Schema;
use WTSI::DNAP::Warehouse::Schema;

with qw(MooseX::Getopt
        npg_tracking::util::db_config);

our $VERSION = '0';

Readonly::Scalar my $LIMS_URL_KEY => q[lims_url];

has '+config_data' => (
  metaclass  => 'NoGetopt',
);

has '+config_file_name' => (
  documentation => 'The name of the config. file, where the server URL ' .
                   'to report to is defined, defaults to npg_tracking-Schema',
);
sub _build_config_file_name {
  return q[npg_tracking-Schema];
}

has '+config_file' => (
  documentation => 'A full path to the configuration file, by default ' .
                   'the file is in the .npg directory of the home directory',
);

has 'qc_schema' => (
  isa        => 'npg_qc::Schema',
  is         => 'ro',
  lazy       => 1,
  builder    => '_build_qc_schema',
  metaclass  => 'NoGetopt',
);
sub _build_qc_schema {
  return npg_qc::Schema->connect();
}

has 'mlwh_schema' => (
  isa        => 'WTSI::DNAP::Warehouse::Schema',
  is         => 'ro',
  lazy       => 1,
  builder    => '_build_mlwh_schema',
  metaclass  => 'NoGetopt',
);
sub _build_mlwh_schema {
  return WTSI::DNAP::Warehouse::Schema->connect();
}

has 'verbose'     => (
  isa           => 'Bool',
  is            => 'ro',
  default       => 0,
  documentation => 'print verbose messages, defaults to false',
);

has 'dry_run' => (
  isa           => 'Bool',
  is            => 'ro',
  default       => 0,
  documentation => 'dry run',
);

sub lims_url {
  my $self = shift;
  my $url = $self->config_data->{$LIMS_URL_KEY};
  if (!defined $url || ($url eq q[])) {
    croak 'LIMS server url is not defined in ' . $self->config_file;
  }
  return $url;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

npg_qc::report::common

=head1 SYNOPSIS

=head1 DESCRIPTION

Moose role. Common options/attributes for reporter scripts.

=head1 SUBROUTINES/METHODS

=head2 config_file_name

The name of the configuration file where the server URL to report to is
defined, defaults to C<npg_tracking-Schema>. This attribute is inherited from
the C<npg_tracking::util::db_config> role.

=head2 config_file

A full path to the configuration file. This attribute is inherited from
the C<npg_tracking::util::db_config> role. By default the file is in the
C<$HOME/.npg> directory and the name of the file is given by the
C<config_file_name> attribute.

=head2 config_data

The contents of the relevant section (live, dev, etc) of the configuration
file. This attribute is inherited from the C<npg_tracking::util::db_config>
role.

=head2 verbose

Boolean verbose flag, false by default.

=head2 dry_run

Dry run flag. No reporting, no marking as reported in the qc database.

=head2 qc_schema

An attribute - the DBIx schema to use for the qc database.
Defaults to npg_qc::Schema.

=head2 mlwh_schema

An attribute - the DBIx schema to use for ml warehouse database.
Defaults to WTSI::DNAP::Warehouse::Schema.

=head2 lims_url

Returns the base URL of the LIMS server to which the reports are sent.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item MooseX::Getopt

=item Carp

=item npg_qc::Schema

=item WTSI::DNAP::Warehouse::Schema

=item npg_tracking::util::db_config

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018, 2022 Genome Research Ltd.

This file is part of NPG.

NPG is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
