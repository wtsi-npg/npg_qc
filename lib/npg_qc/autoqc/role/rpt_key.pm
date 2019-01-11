package npg_qc::autoqc::role::rpt_key;

use Moose::Role;
use List::MoreUtils qw/ uniq /;
use Try::Tiny;
use Readonly;

with 'npg_tracking::glossary::rpt';

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

Readonly::Scalar my $LESS    => -1;
Readonly::Scalar my $MORE    =>  1;
Readonly::Scalar my $EQUAL   =>  0;
Readonly::Scalar my $DELIM   =>  q[-];

=head1 NAME

npg_qc::autoqc::role::rpt_key

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 rpt_key

Rpt list string corresponding to a result object ($self).

=cut
sub rpt_key {
    my $self = shift;
    return $self->can('get_rpt_list') ?
      $self->get_rpt_list() :
      $self->deflate_rpt();
}

=head2 lane_rpt_key_from_key

Given an rpt key, returns an rpt key for corresponding lane

=cut
sub lane_rpt_key_from_key {
    my ($self, $rpt_key) = @_;
    my $h = $self->inflate_rpt($rpt_key);
    delete $h->{'tag_index'};
    return  $self->deflate_rpt($h);
}

=head2 is_lane_key

Returns true if a key is a single rpt key for a lane,
otherwise returns false.

=cut
sub is_lane_key {
    my ($self, $key) = @_;
    my $a = $self->inflate_rpts($key);
    if (@{$a} == 1 && !defined $a->[0]->{'tag_index'}) {
        return 1;
    }
    return;
}


=head2 rpt_list2one_hash

Argument - rpt list string.
Inflates the argument rpt list string to a list of hash references,
each hash representing an individual rpt key, then performs map-reduce
operation on the list. A single hash reference is returned.

  use Data::Dumper;

  print Dumper $obj->rpt_list2one_hash('1:2:3');
  $VAR1 = {
            'id_run' => '1',
            'position' => '2',
            'tag_index' => '3'
          };
  print Dumper $obj->rpt_list2one_hash('1:2:3;1:3:3');
  $VAR1 = {
            'id_run' => '1',
            'position' => '2-3',
            'tag_index' => '3'
          }; 

=cut
sub rpt_list2one_hash {
    my ($self, $rpt_list) = @_;
    my $a = $self->inflate_rpts($rpt_list);
    my $h = {};
    if (@{$a} == 1) {
        $h = $a->[0];
    } else {
        for my $name (qw/id_run position tag_index/) {
            my @values = uniq map {defined $_->{$name} ? $_->{$name} : 'none'} @{$a};
            if (@values > 1 || $values[0] ne 'none') {
                $h->{$name} = join $DELIM, @values;
            }
        }
    }
    return $h;
}

=head2 rpt_list2first_rpt_key

Return the first rpt key of the argument rpt list.

=cut
sub rpt_list2first_rpt_key {
    my ($self, $rpt_list) = @_;
    my $a = $self->inflate_rpts($rpt_list);
    return $self->deflate_rpt($a->[0]);
}

=head2 inflate_rpt_key

To retain backward compatibility, an alias for rpt_list2one_hash.

=cut
sub inflate_rpt_key {
    my ($self, $key) = @_;
    return $self->rpt_list2one_hash($key);
}


=head2 expand_rpt_key

Argument - rpt list string.
Converts a one-component rpt list string to a human-friendly description.
For a multi-component rpt list returns the argument string without change.

=cut
sub expand_rpt_key {
    my ($self, $key) = @_;

    my $mapping = {id_run=>'run',position=>'lane',tag_index=>'tag',};

    my $map;
    my $s = $key;
    try {
        my $a = $self->inflate_rpts($key);
        if (@{$a} == 1) {
            $map = $a->[0];
        }
    };
    if (defined $map && scalar keys %{$map} >= 2 ) {
        $s = q[run ] . $map->{'id_run'} . q[ lane ] . $map->{'position'};
        if (exists $map->{'tag_index'}) {
            $s .= q[#] . $map->{'tag_index'};
	      }
    }
    return $s;
}

sub _compare_rpt_keys_zero_last {
    my $a_map = __PACKAGE__->rpt_list2one_hash($a);
    my $b_map = __PACKAGE__->rpt_list2one_hash($b);

    return $a_map->{'id_run'} cmp $b_map->{'id_run'} ||
           $a_map->{'position'} cmp $b_map->{'position'} ||
           _compare_tags_zero_last($a_map, $b_map);
}

sub _compare_tags_zero_last {## no critic (RequireArgUnpacking)
  if ( !exists $_[0]->{'tag_index'} && !exists $_[1]->{'tag_index'} ) { return $EQUAL; }
  elsif ( exists $_[0]->{'tag_index'} && exists $_[1]->{'tag_index'} ) {
    if( $_[0]->{'tag_index'} eq '0' ) { return $MORE; }
    elsif ( $_[1]->{'tag_index'} eq '0' ) { return $LESS; }
    else {
      my $tia = $_[0]->{'tag_index'};
      my $tib = $_[1]->{'tag_index'};
      if ($tia !~ /[-]/xms && $tib !~ /[-]/xms) {
        return $tia <=> $tib;
      } else {
        return $tia cmp $tib;
      }
    }
  } elsif ( !exists $_[0]->{'tag_index'} ) { return $LESS; }
  else { return $MORE; }
}

=head2 sort_rpt_keys_zero_last

Sorts the argument list of hash reference of a type returned by expand_rpt_key
method. Returns a sorted list with entries corresponding to tag index zero at
the of each group of run, position, tag_index.

=cut
sub sort_rpt_keys_zero_last{
    my ($self, $keys) = @_;
    my @a = sort _compare_rpt_keys_zero_last @{$keys};
    return @a;
}

=head2 runs_from_rpt_keys

List of run ids

=cut
sub runs_from_rpt_keys {
    my ($self, $keys) = @_;
    my @ar = ();
    foreach my $key (@{$keys}) {
      my $a = $self->inflate_rpts($key);
      push @ar, (map { $_->{'id_run'} } @{$a});
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
        if (exists $self->inflate_rpt_key($key)->{'tag_index'}) {
            return 1;
        }
    }
    return 0;
}

1;
__END__


=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Try::Tiny

=item Readonly

=item List::MoreUtils

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 GRL

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
