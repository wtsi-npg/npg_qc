package npg_qc_viewer::Model::UpstreamTagsCheck;

use Carp;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Model' }

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc_viewer::Model::UpstreamTagsCheck - post-process upstream_tags results (e.g. re-sort)

=head1 SYNOPSIS

=head1 DESCRIPTION

Catalyst model for handling upstream_tags qc check results

=head1 SUBROUTINES/METHODS

=head2 sort_unexpected_tags

Returns a JSON string containing upstream tags results sorted by perfect match read count

=cut

## no critic qw(BuiltinFunctions::ProhibitReverseSortBlock)
sub sort_unexpected_tags {
  my ($self, $upstream_tags_results) = @_;

  if($upstream_tags_results->unexpected_tags and @{$upstream_tags_results->unexpected_tags}) {
    $upstream_tags_results->{unexpected_tags} = [ sort { $b->{perfect_match_count} <=> $a->{perfect_match_count}; } (@{$upstream_tags_results->unexpected_tags}) ];
  }

  return $upstream_tags_results;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Carp

=item Moose

=item namespace::autoclean

=item Catalyst::Model

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Kevin Lewis E<lt>kl2@sanger.ac.ukE<gt>

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

