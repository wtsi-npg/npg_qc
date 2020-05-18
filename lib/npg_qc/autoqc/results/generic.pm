package npg_qc::autoqc::results::generic;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Digest::MD5 qw/md5_hex/;

extends qw(npg_qc::autoqc::results::base);

our $VERSION = '0';

has 'pp_name' =>  (
  isa      => 'Str',
  is       => 'rw',
  required => 0,
);

has 'pp_version' =>  (
  isa      => 'Str',
  is       => 'rw',
  required => 0,
);

has 'pp_metrics_name' =>  (
  isa      => 'Str',
  is       => 'rw',
  required => 0,
);

has 'metrics' =>  (
  isa     => 'HashRef',
  is      => 'rw',
  default => sub { return {}; },
);

has 'supplimentary_info' =>  (
  isa     => 'HashRef',
  is      => 'rw',
  default => sub { return {}; },
);

around 'filename_root' => sub {
  my $orig = shift;
  my $self = shift;
  return join q[.],
         $self->$orig(),
         md5_hex(sprintf '%s%s%s',
                         $self->pp_name || q[],
                         $self->pp_version || q[],
                         $self->pp_metrics_name || q[]);
};

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

 npg_qc::autoqc::results::generic

=head1 SYNOPSIS

 my $g = npg_qc::autoqc::results::generic->new(rpt_list => '40:1:1');

=head1 DESCRIPTION

An autoqc result class that wraps in a flexible way around
arbitrary QC metrics, which are produred by portable third-party
pipelines (pp).

=head1 SUBROUTINES/METHODS

=head2 pp_name

An attribute, the name of the portable pipeline. While the attribute
is optional in this object, it should be set in order to save the
results to the database.

=head2 pp_name

An attribute, the version of the portable pipeline, optional.

=head2 pp_mietrics_name

An attribute, the name of the captured metrics. While the attribute
is optional in this object, it should be set in order to save the
results to the database.

=head2 metrics

A hash reference attribute, defaults to an empty hash. The content
of the captured metrics. The hash can wrap around a deeply nested data
structure. This data structure is going to be serialized to JSON when
saved either to a file or to a datababase.

=head2 supplimentary_info

A hash reference attribute, defaults to an empty hash. This optional
metrics provides any metadata or information that is necessary for
evaluation and further processing of data in the metrics attribute.

=head2 filename_root

This class changes the filename_root attribute of the parent class.
The md5 checksum of the pp_name, pp_version and pp_metrics_name
attribute values is appended to the standard filename_root to allow
for coexistance of metrics from different pipelines in the same
directory.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item Digest::MD5

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
