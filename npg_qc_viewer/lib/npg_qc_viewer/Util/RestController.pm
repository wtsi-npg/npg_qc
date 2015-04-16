package npg_qc_viewer::Util::RestController;

use Moose::Role;
use Carp;
use Readonly;

our $version = '0';

## no critic (Documentation::RequirePodAtEnd)

Readonly::Scalar my $ERROR_CODE_STRING   => q[SeqQC error code ];

=head1 NAME

npg_qc_viewer::Util::RestController

=head1 SYNOPSIS

=head1 DESCRIPTION

Moose role for extending functionality of REST controller by adding
subs for extra response codes.

=head1 SUBROUTINES/METHODS

=head2 status_unauthorized

 Returns a "401 Unauthorized" response. Takes a "message" argument
 as a scalar, which will become the value of "error" in the serialized
 response.

=cut

sub status_unauthorized {
    my $self = shift;
    my $c    = shift;
    my %p    = Params::Validate::validate( @_, { message => { type => Params::Validate::SCALAR }, }, );

    $c->response->status(401);
    $c->log->debug( "Status Unauthorized: " . $p{'message'} ) if $c->debug;
    $self->_set_entity( $c, { error => $p{'message'} } );
    return 1;
}

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

=item Readonly

=item Params::Validate

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Jaime Tovar E<lt>jmtc@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 Genome Research Ltd.

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