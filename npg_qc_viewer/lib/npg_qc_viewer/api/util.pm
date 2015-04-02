package npg_qc_viewer::api::util;

use Moose;
use Carp;
use Readonly;
use List::MoreUtils qw/ uniq /;

use npg_qc::autoqc::role::rpt_key;
use npg_qc::autoqc::results::collection;

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd ProhibitMagicNumbers RequireCheckingReturnValueOfEval)

Readonly::Scalar my $LESS    => -1;
Readonly::Scalar my $MORE    =>  1;
Readonly::Scalar my $EQUAL   =>  0;

=head1 NAME

npg_qc_viewer::api::util

=head1 SYNOPSIS

 my $util = npg_qc_viewer::api::util->new();

=head1 DESCRIPTION

Handy routines for run-lane map hashes and run-position-tag keys
wrapped into a Moose object.

=head1 SUBROUTINES/METHODS

=head2 inflate_rpt_key

Extract id_run, position and tag_index from run-position-tag key and return as a hash ref

=cut
sub inflate_rpt_key {
    my ($self, $key) = @_;
    my $delim = $npg_qc::autoqc::role::rpt_key::RPT_KEY_DELIM;
    my @values = split /$delim/smx, $key;
    if (@values < 2 || @values > 3) {
        croak qq[Invalid rpt key $key];
    }
    my $map = {};
    $map->{id_run} = $values[0];
    $map->{position} = $values[1];
    if (@values == 3) {
        $map->{tag_index} = $values[2];
    }
    return $map;
}

=head2 expand_rpt_key

Extract id_run, position and tag_index from run-position-tag key and return as a readable string

=cut
sub expand_rpt_key {
    my ($self, $key) = @_;

    my $mapping = {id_run=>'run',position=>'lane',tag_index=>'tag',};

    my $map;
    my $s = q[];
    eval {
        $map = $self->inflate_rpt_key($key);
    };
    if (defined $map && scalar keys %{$map} >= 2 ) {
        $s = q[run ] . $map->{id_run} . q[ lane ] . $map->{position};
        if (exists $map->{tag_index}) {
            $s .= q[#] . $map->{tag_index};
	}
    }
    return $s;
}

sub _compare_rpt_keys {

    my $self = undef;
    my $a_map = inflate_rpt_key($self, $a);
    my $b_map = inflate_rpt_key($self, $b);

    return $a_map->{id_run} <=> $b_map->{id_run} ||
           $a_map->{position} <=> $b_map->{position} ||           ( (!exists $a_map->{tag_index} && !exists $b_map->{tag_index}) ? $EQUAL : (
               (exists $a_map->{tag_index}  && exists $b_map->{tag_index}) ? ($a_map->{tag_index} <=> $b_map->{tag_index}) : (
                   !exists $a_map->{tag_index} ? $LESS : $MORE
               )
             )
	   );
}

=head2 sort_rpt_keys

Sorts the argument list and returns a sorted list

=cut
sub sort_rpt_keys {
    my ($self, $keys) = @_;
    my @a = sort _compare_rpt_keys @{$keys};
    return @a;
}

=head2 runs_from_rpt_keys

List of run ids

=cut
sub runs_from_rpt_keys {
    my ($self, $keys) = @_;
    my @ar = ();
    foreach my $key (@{$keys}) {
      my $m = $self->inflate_rpt_key($key);
      push @ar, $m->{'id_run'};
    }
    @ar = sort { $a <=> $b } uniq @ar;
    return @ar;
}

=head2 has_plexes

Returns 1 if at least one key is for a plex, otherwise returns 0

=cut
sub has_plexes {
    my ($self, $rl_map_keys) = @_;
    foreach my $key (@{$rl_map_keys}) {
        if (exists $self->inflate_rpt_key($key)->{tag_index}) {
            return 1;
        }
    }
    return 0;
}

=head2 rl_map2collection

Merges a per-lane set of collections to a single collection. Keeps the original set intact.

=cut
sub rl_map2collection {
    my ($self, $rl_map) = @_;
    my $collection = npg_qc::autoqc::results::collection->new();
    foreach my $key (keys %{$rl_map}) {
        my $temp_collection = $rl_map->{$key};
        if ($temp_collection) {
            $collection->add($temp_collection->results);
        }
    }
    return $collection;
}

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item Readonly

=item List::MoreUtils

=item npg_qc::autoqc::role::rpt_key

=item npg_qc::autoqc::results::collection

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

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

