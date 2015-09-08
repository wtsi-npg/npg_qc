package npg_qc::autoqc::results::samtools_stats;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use npg_tracking::util::types;
use Compress::Zlib;
use Perl6::Slurp;
use File::Spec::Functions qw( splitpath );
use Carp;

extends qw(npg_qc::autoqc::results::base);

our $VERSION = '0';

has 'stats_file'     => (
    isa        => 'NpgTrackingReadableFile',
    is         => 'ro',
    required   => 1,
);

has 'filter'         => (
    is         => 'ro',
    isa        => 'Str',
    required   => 0,
    lazy_build => 1,
);
sub _build_filter {
  my ($self, $path) = @_;

  my ($volume, $directories, $file) = splitpath($self->stats_file);
  my ($filter) = $file =~ /_([[:lower:][:upper:][:digit:]]+)[.]stats\Z/xms;
  if (!$filter) {
    croak "Failed to get filter from $path";
  }

  my $subset = $self->composition_subset();
  $subset = $subset ? $subset . q[_] : q[];
  return  ($file =~ / \d _ $subset $filter [.]stats\Z/xms) ? $filter : undef;
}

has 'stats'         => (
    is         => 'ro',
    isa        => 'Str',
    required   => 0,
    lazy_build => 1,
    predicate  => '_has_stats',
);
sub _build_stats {
  my $self = shift;
  return compress(slurp $self->stats_file);
}

override 'execute' => sub {
  my $self = shift;
  super();
  $self->stats();
  return;
};

override 'filename_root' => sub  {
  my $self = shift;
  return $self->filename_root_from_filename($self->stats_file);
};

__PACKAGE__->meta->make_immutable;

1;
__END__


=head1 NAME

npg_qc::autoqc::results::samtools_stats

=head1 SYNOPSIS

=head1 DESCRIPTION

A class representing a filter-specific samtools stats file.

=head1 SUBROUTINES/METHODS

=head2 stats_file

Attribute, a path of the samtools stats file

=head2 filter

Attribute, the filter name that was used by samtools to produce the stats,
required.

=head2 stats

Attribute, compressed content of the samtool stats file, required

=head2 filename_root

Extends the parent method, appends filter name to the filename root.

=head2 execute

Method forcing all lazy attributes of the object to be built.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item npg_tracking::util::types

=item Compress::Zlib

=item Perl6::Slurp

=item File::Spec::Functions

=item Carp

=item npg_qc::autoqc::results::base

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL

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
