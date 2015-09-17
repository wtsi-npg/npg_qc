package npg_qc::mqc::role::TimeZoneConsumerRole;

use Readonly;
use DateTime;
use DateTime::TimeZone;

our $VERSION = '0';

use Moose::Role;

sub _get_time_now {
  return DateTime->now(time_zone => DateTime::TimeZone->new(name => q[local]));
}

no Moose;

1;

__END__


=head1 NAME

  npg_qc::mqc::role::MQCEntRole

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=head2 

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 Genome Research Ltd

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