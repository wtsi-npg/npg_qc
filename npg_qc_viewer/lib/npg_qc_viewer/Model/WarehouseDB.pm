package npg_qc_viewer::Model::WarehouseDB;

use Moose;
use Carp;
use Readonly;

BEGIN { extends 'Catalyst::Model::DBIC::Schema' }

our $VERSION  = '0';
## no critic (Documentation::RequirePodAtEnd ProhibitNoisyQuotes)

Readonly::Scalar our $LESS => -1;
Readonly::Scalar our $MORE =>  1;
Readonly::Scalar our $SAME =>  0;
Readonly::Scalar our $SAMPLE_TUBE_ASSET_TYPE => q[SampleTube];

=head1 NAME

npg_qc_viewer::Model::WarehouseDB

=head1 SYNOPSIS

=head1 DESCRIPTION

Catalyst::Model::DBIC::Schema Model using schema npg_warehouse::Schema

=head1 SUBROUTINES/METHODS

=cut


__PACKAGE__->config(
    schema_class => 'npg_warehouse::Schema',
    connect_info => [], #a fall-back position if connect_info is not defined in the config file
);

=head2  _library_list_sort

Compare routine for library list sorting

=cut
sub _library_list_sort {
    return ($a->asset_name && $b->asset_name) ? ($a->asset_name cmp $b->asset_name) :
           ((!$a->asset_name && !$b->asset_name) ? $SAME :
            (!$a->asset_name && $b->asset_name) ? $MORE : $LESS
           )
}


=head2 libraries_list

Sorted list of result sets representing a library (asset id and name).

=cut
sub libraries_list {
    my $self = shift;

    my @libs = $self->resultset('NpgInformation')->search(
		  {   asset_id => {'!=' => undef},},
                  {
                      columns => [qw/asset_name asset_id lane_type/],
                      distinct => 1,
	          },
	        )->all;
    push @libs,  $self->resultset('NpgPlexInformation')->search(
                  {   asset_id => {'!=' => undef,},},
                  {
                      columns => [qw/asset_name asset_id/],
                      distinct => 1,
	          },
	        )->all;
    @libs = sort _library_list_sort @libs;
    return \@libs;
}


=head2 studies_list

An ordered result set with study ids and names

=cut
sub studies_list {
    my $self = shift;
    my $rs = $self->resultset('CurrentStudy')->search(
		  { },
                  {
                      columns  => [qw/internal_id name/],
                      distinct => 1,
                      order_by => 'name',
	          },
	        );
    return $rs;
}

=head2 samples_list

A sorted list of hash reference representing samples (sample id and name)

=cut
sub samples_list {
    my $self = shift;

    my $where = {   'sample_id' => {'!=' => undef,},};
    my $columns = {
                      columns => [qw/sample_id/],
                      distinct => 1,
	          };
    my $samples = {};
    foreach my $table (qw/NpgInformation NpgPlexInformation/) {
        my $rs = $self->resultset($table)->search($where, $columns);
        while (my $row = $rs->next) {
            my $sample_id = $row->sample_id;
            if ($sample_id) {
                if (!exists $samples->{$sample_id}) {
                    my $name = $row->sample_name;
                    if ($name) {
                        $samples->{$sample_id} = $name;
		    }
	        }
	    }
        }
    }

    my @pairs = ();
    foreach my $sample_id (keys %{$samples}) {
        push @pairs, {id => $sample_id, name => $samples->{$sample_id}, };
    }
    @pairs = sort { $a->{name} cmp $b->{name} } @pairs;
    return \@pairs;
}

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Readonly

=item Catalyst::Model::DBIC::Schema

=item npg_warehouse::Schema

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David Jackson

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

