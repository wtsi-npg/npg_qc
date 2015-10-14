package npg_qc::autoqc::role::rpt_key;

use Moose::Role;
use Carp;
use List::MoreUtils qw/ uniq /;
use Try::Tiny;
use Readonly;

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

Readonly::Scalar our $RPT_KEY_DELIM => q[:];
Readonly::Scalar our $RPT_KEY_MIN_LENGTH => 2;
Readonly::Scalar our $RPT_KEY_MAX_LENGTH => 3;

Readonly::Scalar my $LESS    => -1;
Readonly::Scalar my $MORE    =>  1;
Readonly::Scalar my $EQUAL   =>  0;

=head1 NAME

npg_qc::autoqc::role::rpt_key

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 rpt_key

A string concatenating id_run, position and tag index (where present)

=cut
sub rpt_key {
    my ($obj) = @_;

    my $key = join $RPT_KEY_DELIM, $obj->id_run, $obj->position;
    if ($obj->can('tag_index') && defined $obj->tag_index) {
        $key = join $RPT_KEY_DELIM, $key,  $obj->tag_index;
    }
    return $key;
}

=head2 lane_rpt_key_from_key

Given an rpt key, retuens an rpt key for corresponding lane

=cut
sub lane_rpt_key_from_key {
    my ($self, $rpt_key) = @_;
    my $h = $self->inflate_rpt_key($rpt_key);
    return join $RPT_KEY_DELIM, $h->{'id_run'}, $h->{'position'};
}

=head2 inflate_rpt_key

Extract id_run, position and tag_index from rpt key and return as a hash ref

=cut
sub inflate_rpt_key {
    my ($self, $key) = @_;

    my @values = split /$RPT_KEY_DELIM/smx, $key;
    if (@values < $RPT_KEY_MIN_LENGTH || @values > $RPT_KEY_MAX_LENGTH) {
        croak qq[Invalid rpt key $key];
    }
    my $map = {};
    $map->{'id_run'} = $values[0];
    $map->{'position'} = $values[1];
    if (@values == $RPT_KEY_MAX_LENGTH) {
        $map->{'tag_index'} = $values[2];
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
    try {
        $map = $self->inflate_rpt_key($key);
    };
    if (defined $map && scalar keys %{$map} >= 2 ) {
        $s = q[run ] . $map->{'id_run'} . q[ lane ] . $map->{'position'};
        if (exists $map->{'tag_index'}) {
            $s .= q[#] . $map->{'tag_index'};
	      }
    }
    return $s;
}

sub _compare_rpt_keys {

    my $a_map = __PACKAGE__->inflate_rpt_key($a);
    my $b_map = __PACKAGE__->inflate_rpt_key($b);

    return $a_map->{'id_run'} <=> $b_map->{'id_run'} ||
           $a_map->{'position'} <=> $b_map->{'position'} ||
           ( (!exists $a_map->{'tag_index'} && !exists $b_map->{'tag_index'})  ? $EQUAL :
             ( (exists $a_map->{'tag_index'}  && exists $b_map->{'tag_index'}) ?
               ($a_map->{'tag_index'} <=> $b_map->{'tag_index'}) :
               (!exists $a_map->{'tag_index'} ? $LESS : $MORE)
             )
	         );
}

sub _compare_rpt_keys_zero_last { ## no critic (RequireArgUnpacking)
  my $a_map = __PACKAGE__->inflate_rpt_key($a);
  my $b_map = __PACKAGE__->inflate_rpt_key($b);

  return $a_map->{'id_run'} <=> $b_map->{'id_run'} ||
         $a_map->{'position'} <=> $b_map->{'position'} ||
         _compare_tags_zero_last($a_map, $b_map);
}

sub _compare_tags_zero_last {## no critic (RequireArgUnpacking)
  if ( !exists $_[0]->{'tag_index'} && !exists $_[1]->{'tag_index'} ) { return $EQUAL; }
  elsif ( exists $_[0]->{'tag_index'} && exists $_[1]->{'tag_index'} ) {
    if( $_[0]->{'tag_index'} == 0 ) { return $MORE; }
    elsif ( $_[1]->{'tag_index'} == 0 ) { return $LESS; }
    else { return $_[0]->{'tag_index'} <=> $_[1]->{'tag_index'}; } 
  } elsif ( !exists $_[0]->{'tag_index'} ) { return $LESS; }
  else { return $MORE; }
}

=head2 sort_rpt_keys

Sorts the argument list and returns a sorted list

=cut
sub sort_rpt_keys {
    my ($self, $keys) = @_;
    my @a = sort _compare_rpt_keys @{$keys};
    return @a;
}

=head2 sort_rpt_keys_zero_last

Sorts the argument list and returns a sorted list with tag_index = 0 at the end
of each group of run position tag_index.

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
        if (exists $self->inflate_rpt_key($key)->{'tag_index'}) {
            return 1;
        }
    }
    return 0;
}

=head2 rpt_key_delim

A string used to concatenate rpt_key

=cut
sub rpt_key_delim {
    return $RPT_KEY_DELIM;
}

1;
__END__


=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Try::Tiny

=item Carp

=item Readonly

=item List::MoreUtils

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
