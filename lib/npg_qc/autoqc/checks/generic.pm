package npg_qc::autoqc::checks::generic;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use st::api::lims;

extends qw(npg_qc::autoqc::checks::check);

## no critic (Documentation::RequirePodAtEnd)
our $VERSION = '0';

=head1 NAME

npg_qc::autoqc::checks::generic

=head1 SYNOPSIS

=head1 DESCRIPTION

This class is a factory for creating npg_qc::autoqc::results::generic
type objects. It does not provide any fuctionality in its execute()
method. For convenience it provides access to LIMS data via its
lims attribute.  

=head1 SUBROUTINES/METHODS

=cut

=head2 lims

A lazy-built attribute, the st::api::lims object corresponding
to this object's rpt_list attribute. 

=cut

has 'lims' => (
  isa        => 'st::api::lims',
  is         => 'ro',
  lazy_build => 1,
);
sub _build_lims {
  my $self = shift;
  return st::api::lims->new(rpt_list => $self->rpt_list);
}

=head2 execute

This method is a stab, it does not provide any functionality and
is retained for compatibility with the autoqc framework. It does
not extend the parent's execute() method.

=cut

sub execute {
  return;
}

=head2 run

This method is a simple wrapper around a routine for serializing
the result object to JSON and saving the JSON string to a file
system. The qc_out attribute of this object is used as a directory
for creating a JSON file. An error might be raised if the qc_out
attribute is not set by the caller. The method does not extent the
parent's run() method.

=cut

sub run {
  my $self = shift;
  $self->result->store($self->qc_out->[0]);
  return;
}

__PACKAGE__->meta->make_immutable();

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item st::api::lims

=back

=head1 AUTHOR

Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2020 Genome Research Ltd.

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
