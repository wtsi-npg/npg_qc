package npg_qc_viewer::Model::GenotypeCheck;

use Carp;
use Moose;
use JSON;
use File::Slurp;

use npg_qc::autoqc::qc_store;
use npg_qc::autoqc::qc_store::options qw/$PLEXES/;

BEGIN { extends 'Catalyst::Model' }

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc_viewer::Model::GenotypeCheck - access to supplementary genotype check data

=head1 SYNOPSIS

=head1 DESCRIPTION

Catalyst model for accessing genotype check data

=head1 SUBROUTINES/METHODS

=head2 fetch_genotype_json

Returns a JSON string containing genotype check data

=cut
sub fetch_genotype_json { ## no critic (ProhibitManyArgs)
  my ($self, $id_run, $position, $tag_index, $sequenom_plex, $db_lookup) = @_;

  my %init = ();
  if(defined $db_lookup) {
    $init{'use_db'} = $db_lookup;
  }
  my $qcs=npg_qc::autoqc::qc_store->new(%init);
  my $c=$qcs->load_run($id_run, $db_lookup, [ $position ], $PLEXES);

	my $trr;
	if(defined $tag_index) {
		$trr=$c->search({class_name => q[genotype], tag_index => $tag_index, });
	}
	else {
		$trr=$c->slice(q[class_name], q[genotype]);
	}

  return $trr;
}

=head2 fetch_composite_genotype_data

Returns a hash ref with plex_name keys and JSON string values containing composite genotype check data

=cut
sub fetch_composite_genotype_data {
	my ($self, $library_id) = @_;
	my $cgc;

	if($library_id and defined npg_qc_viewer->config->{'Model::GenotypeCheck'}->{'composite_results_loc'}) {
		my $composite_results_loc = npg_qc_viewer->config->{'Model::GenotypeCheck'}->{'composite_results_loc'};

		if(opendir my $dh, $composite_results_loc) {
			while(my $plex_dir = readdir $dh) {
				next if $plex_dir =~ /^[.]/smx;

				my $cgd = $self->fetch_cgd_for_plex($library_id, $plex_dir, $composite_results_loc);
				if($cgd) {
					$cgc->{$plex_dir} = $cgd;
				}
			}
		}
		else {
			carp q[Failed to open composite_results_location: ], $composite_results_loc;
		}
	}

	return $cgc;
}

=head2 fetch_cgd_for_plex

Returns hash ref generated from the JSON string containing composite genotype check data
  for the specified plex (or marker set)

=cut
sub fetch_cgd_for_plex {
	my ($self, $library_id, $plex_name, $composite_results_loc) = @_;
	my $cgd;

	## no critic qw(ControlStructures::ProhibitUnlessBlocks)
	unless(defined $library_id and $library_id) {
		return;
	}
	## use critic

	$plex_name ||= q[W30467];
	$composite_results_loc ||= npg_qc_viewer->config->{'Model::GenotypeCheck'}->{'composite_results_loc'};

	my $cgc_file = $library_id . q[.json];
	##no critic (ProhibitMagicNumbers)
	my $cgc_path = join q[/], $composite_results_loc, $plex_name, substr($library_id, 0, 1), substr($library_id, 1, 3), $library_id, $cgc_file;

	##use critic

	if(-f $cgc_path) {
		my $s = read_file($cgc_path);
		if($s) {
			$cgd = from_json($s);
		}
	}

	return $cgd;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Carp

=item Moose

=item Catalyst::Model

=item JSON

=item File::Slurp

=item npg_qc::autoqc::qc_store

=item npg_qc::autoqc::qc_store::options

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Kevin Lewis E<lt>kl2@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Genome Research Ltd

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

