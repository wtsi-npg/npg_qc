package npg_qc::autoqc::results::adapter;

use Moose;
use namespace::autoclean;
extends qw(npg_qc::autoqc::results::result);
with qw(npg_qc::autoqc::role::adapter);

our $VERSION = '0';

has forward_read_filename           => ( is  => 'rw',
                                         isa => 'Maybe[Str]', );
has reverse_read_filename           => ( is  => 'rw',
                                         isa => 'Maybe[Str]', );
has forward_fasta_read_count        => ( is  => 'rw',
                                         isa => 'Int', );
has forward_contaminated_read_count => ( is  => 'rw',
                                         isa => 'Int', );
has forward_blat_hash               => ( is  => 'rw',
                                         isa => 'HashRef', );
has reverse_fasta_read_count        => ( is  => 'rw',
                                         isa => 'Maybe[Int]', );
has reverse_contaminated_read_count => ( is  => 'rw',
                                         isa => 'Maybe[Int]', );
has reverse_blat_hash               => ( is  => 'rw',
                                         isa => 'Maybe[HashRef]', );
has forward_start_counts            => ( is  => 'rw',
                                         isa => 'Maybe[HashRef]', );
has reverse_start_counts            => ( is  => 'rw',
                                         isa => 'Maybe[HashRef]', );

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

    npg_qc::autoqc::results::adapter

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 forward_read_filename Filename for the first (forward) read 

=head2 reverse_read_filename Filename for the second (reverse) read

=head2 forward_fasta_read_count

=head2 forward_contaminated_read_count

=head2 forward_blat_hash

=head2 reverse_fasta_read_count

=head2 reverse_contaminated_read_count

=head2 reverse_blat_hash

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

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>
John O'Brien E<lt>jo3@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 GRL

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
