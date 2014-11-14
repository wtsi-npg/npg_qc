package npg_qc_viewer::Controller::AjaxProxy;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::AjaxProxy' }

our $VERSION = '0';

1;
__END__

=head1 NAME

npg_qc_viewer::Controller::AjaxProxy

=head1 SYNOPSIS

=head1 DESCRIPTION

A Catalyst Controller implementing a proxy for Ajax calls.
If both the remote_sites and protocols attributes set,
uses the validate method to validate the requested URLs.

Request example: http://localhost:3000/myproxy?url=http://www.othersite.com/somepage

Example of configuration in the XML configuration file:

  <Controller AjaxProxy>
    remote_sites  internal.npgtest.dodo
    remote_sites  www.npgtest.dodo
    protocols     http
    protocols     https
  </Controller>

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item namespace::autoclean

=item Moose

=item Catalyst::Controller::AjaxProxy

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
