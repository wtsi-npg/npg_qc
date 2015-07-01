package npg_qc_viewer::Controller::Data;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

our $VERSION   = '0';
## no critic (Documentation::RequirePodAtEnd Documentation::PodSpelling Subroutines::ProhibitBuiltinHomonyms)

=head1 NAME

npg_qc_viewer::Controller::Data - Catalyst Controller for serving data

=head1 VERSION

$Revision$

=head1 SYNOPSIS


=head1 DESCRIPTION

Catalyst Controller.

=head1 SUBROUTINES/METHODS

=cut

=head2 base 

Action for the base controller path

=cut
sub base :Chained('/') :PathPart('data') :CaptureArgs(0) {
    my ($self, $c) = @_;
    return;
}


=head2 genotype

An action for serving genotype check results JSON data for a run/lane

=cut
sub genotype :Chained('base') :PathPath('genotype') :Args(0) {
	my ($self, $c) = @_;
	my $results_json = q{[]};

	if(defined $c->request->query_parameters->{run} and defined $c->request->query_parameters->{lane}) {

		my $id_run = $c->request->query_parameters->{run};
		my $position = $c->request->query_parameters->{lane};
		my $tag_index = $c->request->query_parameters->{tag};
		my $db_lookup = $c->request->query_parameters->{db_lookup};
		my $sequenom_plex = $c->request->query_parameters->{plex};

		my $j = $c->model(q[GenotypeCheck])->fetch_genotype_json($id_run, $position, $tag_index, $sequenom_plex, $db_lookup);

		my @processed_results = ();   # TBD: store all processed results here, then apply to_json() at the end
		$results_json = q{};
		my $s = q{};
		my $x = 1;
		for my $e (@{$j->results}) {
			#carp q[Controller processing result element ], $x++;
			$s = $e->json;        # initial json string
			$s =~ tr/\n//d;
			$results_json .= ($results_json? q/,/: q/[/) . $s;   # add to the JSON array
		}
		$results_json .= q{]};
	}

	$c->res->content_type(q[application/json]);
	$c->res->body($results_json);

	return;
}

=head2 tags_reporters

An action for serving tags_reporters check results JSON data for a run/lane

=cut
sub tags_reporters :Chained('base') :PathPath('tags_reporters') :Args(0) {
	my ($self, $c) = @_;
	my $s = q[{"msg":"No data"}];;

	if(defined $c->request->query_parameters->{run} and defined $c->request->query_parameters->{lane}) {

		my $id_run = $c->request->query_parameters->{run};
		my $position = $c->request->query_parameters->{lane};
		my $j = $c->model(q[TagsReporters])->fetch_tags_reporters_json($id_run, $position, 0);

		my $tmp = $j->results;
		$tmp = _cook($tmp->[0]);
		$s = $tmp->json;      # initial json string
		$s =~ tr/\n//d;
	}

	# Temporary data munging
	$s = _reformat_trck_results($s);

	$c->res->content_type(q[application/json]);
	$c->res->body($s);

	return;
}

=head2 _reformat_trck_results

Function to reformat data into a format useful to SeqQC display

=cut
sub _reformat_trck_results {
	my ($s) = @_;

	my $h = from_json($s);
	my @t = @{$h->{tag_list}};
	my @ar=@{$h->{amp_rows}};
	my @r = (map { $_->{reporter_id}; } (@ar));
	my @links = ();
	for my $ri (0..$#ar) {
		for my $ti (0..$#t) {
			push @links, { value => $ar[$ri]->{counts}->[$ti], tag => $ti, reporter => $ri};
		}
	}
	my @tags = ();
	for my $e (@t) {
		push @tags, { name => $e };
	}
	my @reporters = ();
	for my $e (@r) {
		push @reporters, { name => $e };
	}
	my $result = { reporters => \@reporters, tags => \@tags, links => \@links, };
	my $out=to_json($result);

	return $out;
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

=item Catalyst::Controller

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
