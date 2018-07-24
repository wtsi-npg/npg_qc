package npg_qc::autoqc::qc_store::options;

use strict;
use warnings;
use base 'Exporter';
use Readonly;
use Carp;

our $VERSION = '0';

our @EXPORT_OK = qw/ $ALL $PLEXES $LANES $MULTI
                     validate_option
                     option_to_string /;

Readonly::Scalar our $ALL    => 1;
Readonly::Scalar our $PLEXES => 2;
Readonly::Scalar our $LANES  => 3;
Readonly::Scalar our $MULTI  => 4;

Readonly::Hash my %OPTIONS2STRING => ($ALL    => 'ALL',
                                      $PLEXES => 'PLEXES',
                                      $LANES  => 'LANES',
                                      $MULTI  => 'MULTI');

sub validate_option {
  my $o = shift;
  if (!$OPTIONS2STRING{$o}) {
    croak qq[Unknown option for loading qc results: $o];
  }
}

sub option_to_string {
  my $o = shift;
  my $s = $OPTIONS2STRING{$o};
  $s or croak qq[Unknown option for loading qc results: $o];
  return $s;
}

1;

__END__

=head1 NAME

npg_qc::autoqc::qc_store::options

=head1 SYNOPSIS

=head1 DESCRIPTION

Constants to define retrival options for autoqc results

=head1 SUBROUTINES/METHODS

=head2 validate_option

=head2 option_to_string

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Readonly

=item Exporter

=item Carp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

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
