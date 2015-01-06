package npg_tracking::daemon::seqqc;

use Moose;
use Readonly;
extends 'npg_tracking::daemon';

our $VERSION = '0';

Readonly::Array my @HOSTS     => qw(sf2-farm-srv1 sf2-farm-srv2);

# Force Catalyst to use a specific home directory:
# in the shell environment by setting either the CATALYST_HOME
# environment variable or MYAPP_HOME; where MYAPP is replaced
# with the uppercased name of your application, any "::" in the
# name will be replaced with underscores, e.g. MyApp::Web should
# use MYAPP_WEB_HOME. If both variables are set, the MYAPP_HOME
# one will be used.

override '_build_hosts'  => sub {return \@HOSTS;};
override 'command'       => sub { return q[npg_qc_viewer_server.pl -f -p 1959]; };

no Moose;

1;
__END__

=head1 NAME

npg_tracking::daemon::seqqc

=head1 SYNOPSIS


=head1 DESCRIPTION

Metadata for a daemon that starts up a Catalyst server for the SeqQC application.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Readonly

=item npg_tracking::daemon::seqqc

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Genome Research Ltd.

This file is part of NPG software.

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




