package npg_qc_viewer::Controller::Warehouse;

use Moose;
use namespace::autoclean;
use Carp;

BEGIN { extends 'Catalyst::Controller::DBIC::API::RPC' }

our $VERSION  = '0';
## no critic (Documentation::RequirePodAtEnd Subroutines::ProhibitBuiltinHomonyms)

=head1 NAME

npg_qc_viewer::Controller::Warehouse

=head1 SYNOPSIS

=head1 DESCRIPTION

Catalyst Controller.

=head1 SUBROUTINES/METHODS

=head2 base

Can place common logic to start chained dispatch here

=cut
sub base :Chained('/') :PathPart('warehouse') :CaptureArgs(0) {
    my ($self, $c) = @_;
    # Print a message to the debug log
    $c->log->debug('*** Controller Runs ***');
    return;
}


=head2 index

index

=cut
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    $c->response->body('Matched npg_qc_viewer::Controller::Warehouse in Warehouse.');
    return;
}

=head2 rs

Arbitrary result set 

=cut
sub rs :Path :Args(1) {
    my ( $self, $c, $t) = @_;
    ($t) = $t=~/^([[:upper:]]+)/ismx;
    my $rs = $c->model(q(WarehouseDB))->resultset($t);
    $c->response->body("Looked for $t and found ".$rs->count().' results.');
    return;
}

__PACKAGE__->config(
  list_search_exposes => [q[*]],
);


=head2 setup

setup

=cut
sub setup : Chained('/') PathPart('warehouse') CaptureArgs(1) {
    my ( $self, $c, $t) = @_;
    ($t) = $t=~/^([[:upper:]]+)/ismx;
    $self->class(qq(WarehouseDB::$t));
    $self->next::method($c);
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

=item Catalyst::Controller::DBIC::API::RPC

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David Jackson E<lt>dj3@sanger.ac.ukE<gt>

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

