package npg_qc_viewer::View::TT;

use Moose;
use npg_qc_viewer;

BEGIN { extends 'Catalyst::View::TT' }

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc_viewer::View::TT - Template Toolkit View for npg_qc_viewer

=head1 SYNOPSIS

=head1 DESCRIPTION

TT View for npg_qc_viewer.

=head1 SEE ALSO

npg_qc_viewer

=head1 SUBROUTINES/METHODS

=cut

__PACKAGE__->config(
  INCLUDE_PATH => [ npg_qc_viewer->path_to( 'root', 'src' ), ],
  STAT_TTL     => 6000,
  TRIM         => 1,
  PRE_CHOMP    => 1,
  POST_CHOMP   => 1,
);

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Catalyst::View::TT

=item npg_qc_viewer

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown E<lt>ajb@sanger.ac.ukE<gt>

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
