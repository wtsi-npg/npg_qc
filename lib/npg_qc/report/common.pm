package npg_qc::report::common;

use Moose::Role;
use npg_qc::Schema;
use WTSI::DNAP::Warehouse::Schema;

with qw(MooseX::Getopt);

our $VERSION = '0';

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


no Moose::Role;

1;
__END__

=head1 NAME

npg_qc::report::common

=head1 SYNOPSIS

=head1 DESCRIPTION

Moose role. Common options/attributes for reporter scripts.

=head1 SUBROUTINES/METHODS

=head2 verbose

  Boolean verbose flag, false by default.

=head2 dry_run

  Dry run flag. No reporting, no marking as reported in the qc database.

=head2 qc_schema

  An attribute - the schema to use for the qc database.
  Defaults to npg_qc::Schema,

=head2 mlwh_schema

  An attribute - the schema to use for ml warehouse database.
  Defaults to WTSI::DNAP::Warehouse::Schema.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item npg_qc::Schema

=item WTSI::DNAP::Warehouse::Schema

=item MooseX::Getopt

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 GRL

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
