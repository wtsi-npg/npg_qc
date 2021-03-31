package npg_qc::autoqc::results::generic;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Carp;

extends qw(npg_qc::autoqc::results::base);
with    qw(npg_qc::autoqc::role::generic);

our $VERSION = '0';

has 'pp_name' =>  (
  isa      => 'Str',
  is       => 'rw',
  required => 0,
);

has 'doc' =>  (
  isa      => 'HashRef',
  is       => 'rw',
  required => 0,
);

sub set_pp_info {
  my ($self, $pp_name, $pp_version) = @_;

  $pp_name or croak 'Portable pipeline name is required';
  if ($self->pp_name and ($self->pp_name ne $pp_name)) {
    croak 'Cannot reset portable pipeline name';
  }

  $self->pp_name($pp_name);
  $self->set_info('Pipeline_name', $pp_name);
  $pp_version && $self->set_info('Pipeline_version', $pp_version);

  return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

 npg_qc::autoqc::results::generic

=head1 SYNOPSIS

 my $g = npg_qc::autoqc::results::generic->new(rpt_list => '40:1:1');

=head1 DESCRIPTION

An autoqc result class that wraps in a flexible way around
arbitrary QC metrics, which are produred by third-party
pipelines or tools.

=head1 SUBROUTINES/METHODS

=head2 pp_name

An attribute, a distinct descriptor for the pipeline or a tool which
produced the data. While the attribute is optional in this object,
it should be set in order to save the result to the database. This
value forms a part of a unique key in the database representation,
so set accordingly. For example, the tool's or pipeline's version
can be appended to the descriptor.

=head2 doc

A hash reference attribute, no default. A flexible, potentially deeply
nested data structure to accomodate QC output and any supplimentary
data. This data structure is going to be serialized to JSON when
saved either to a file or to a datababase.

=head2 set_pp_info

Given the name and, optionally, version, of the portable pipeline that
produced the data, this method sets relevant attributes of the object.

  $obj->set_pp_info('some_name', 'some_version');
  $obj->set_pp_info('some_name');

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

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
