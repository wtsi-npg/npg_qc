package npg_qc_viewer::Model::SeqStore;

use Carp;
use Moose;
use Readonly;

use npg_common::run::file_finder;

BEGIN { extends 'Catalyst::Model' }

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

Readonly::Scalar our $FILE_EXTENSION => q[fastqcheck];

=head1 NAME

npg_qc_viewer::Model::SeqStore - access to sequence store

=head1 SYNOPSIS

=head1 DESCRIPTION

Catalyst model for accessing both short and long-term sequence store

=head1 SUBROUTINES/METHODS

=head2 files

A list of fastqcheck file paths for a run and position

=cut
sub files {
    my @sargs = @_;
    my $self        = shift @sargs;
    my $rpt_key_map = shift @sargs;
    my $db_lookup   = shift @sargs;

    if (@sargs && (ref $sargs[0]) eq q[ARRAY]) {   # this is a list of paths
        $db_lookup = 0;
        my $all_files = {};
        my $count = 0;
        foreach my $path (@{$sargs[0]}) {
            my $files = $self->_files4one_path($rpt_key_map, $db_lookup, $path);
            foreach my $ftype (keys %{$files}) {
                $all_files->{$ftype} = $files->{$ftype};
            }
        }
        if (scalar keys %{$all_files}) {
            $all_files->{db_lookup} = 0;
    }
        return $all_files;
    } else {
        return $self->_files4one_path($rpt_key_map, $db_lookup);
    }
    return;
}

sub _files4one_path {
    my ($self, $rpt_key_map, $db_lookup, $path) = @_;

    my $ref = {
            position          => $rpt_key_map->{position},
            file_extension    => $FILE_EXTENSION,
            with_t_file       => 1,
            id_run            => $rpt_key_map->{id_run},
            db_lookup         => $db_lookup,
              };
    if (exists $rpt_key_map->{tag_index} && defined $rpt_key_map->{tag_index}) {
        $ref->{tag_index}                = $rpt_key_map->{tag_index};
        $ref->{with_t_file}              = 0;
        if ($path) { $ref->{lane_archive_lookup}  = 0; }
    }
    if ($path) { $ref->{archive_path} = $path; }
    my $finder = npg_common::run::file_finder->new($ref);
    my $files =  $finder->files();
    if (scalar keys %{$files}) {
        $files->{db_lookup} = $finder->db_lookup;
    }
    return $files;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Readonly

=item Carp

=item Moose

=item Catalyst::Model

=item npg_common::run::file_finder

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

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

