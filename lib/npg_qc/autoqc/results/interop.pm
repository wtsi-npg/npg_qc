package npg_qc::autoqc::results::interop;

use Moose;
use namespace::autoclean;

extends qw(npg_qc::autoqc::results::base);
with 'npg_qc::autoqc::role::interop';

our $VERSION = '0';

has 'metrics' =>  (
  isa     => 'HashRef',
  is      => 'rw',
  default => sub { return {}; },
);

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

 npg_qc::autoqc::results::interop

=head1 SYNOPSIS

 my $rObj = npg_qc::autoqc::results::interop->new(rpt_list => '40:1');

=head1 DESCRIPTION

 An autoqc result object that wraps illumina analysis derived from the InterOp files, see
 https://support.illumina.com/content/dam/illumina-support/documents/documentation/software_documentation/sav/sequencing-analysis-viewer-v-2-4-software-guide-15066069-03.pdf

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Steven Leonard E<lt>srl@sanger.ac.ukE<gt><gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2019 GRL

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
