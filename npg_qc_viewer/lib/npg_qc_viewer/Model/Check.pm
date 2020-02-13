package npg_qc_viewer::Model::Check;

use Moose;
use namespace::autoclean;
use npg_qc_viewer;
extends 'Catalyst::Model::Adaptor';

use npg_qc::Schema;
use npg_qc::autoqc::results::collection;

our $VERSION = '0';

my $use_db    = 1;
my $connect_info;
if (defined npg_qc_viewer->config->{'Model::Check'}) {
    if (defined npg_qc_viewer->config->{'Model::Check'}->{'use_db'} &&
            npg_qc_viewer->config->{'Model::Check'}->{'use_db'} eq 'no' ) {
        $use_db = 0;
    }
    if (defined npg_qc_viewer->config->{'Model::Check'}->{'connect_info'}) {
        $connect_info = npg_qc_viewer->config->{'Model::Check'}->{'connect_info'};
    }
}

my $init = {};
if ($use_db && $connect_info) {
    $init->{'qc_schema'} = npg_qc::Schema->connect(map { $connect_info->{$_} } sort keys %{$connect_info});
}
my @check_names = grep { $_ ne 'interop' } @{npg_qc::autoqc::results::collection->new()->checks_list()};
$init->{'checks_list'} = \@check_names;

__PACKAGE__->config( class => 'npg_qc::autoqc::qc_store',
                     args  => $init,
                   );

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

npg_qc_viewer::Model::Check

=head1 SYNOPSIS

=head1 DESCRIPTION

A model for retrieving QC checks both from the database and the file system.

Is configured not to retrieve interop autoqc results even if the underlying class
is able to retrieve them.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Catalyst::Model::Adaptor

=item npg_qc::Schema

=item npg_qc::autoqc::qc_store

=item npg_qc::autoqc::results::collection

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014,2015,2020 Genome Research Ltd.

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

