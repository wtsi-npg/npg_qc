package npg_qc::autoqc::results::spatial_filter;

use Moose;
use namespace::autoclean;
use Carp;
use Perl6::Slurp;

extends qw(npg_qc::autoqc::results::result);
with qw(npg_qc::autoqc::role::result);

our $VERSION = '0';

has '+path'               =>  (
                               required   => 0,
                                        );



has 'num_total_reads'              => (
                                       isa            => 'Maybe[Int]',
                                       is             => 'rw',
                                       required       => 0,
		                                );

has 'num_spatial_filter_fail_reads'=> (
                                       isa            => 'Maybe[Int]',
                                       is             => 'rw',
                                       required       => 0,
		                                );


sub parse_output{
  my ( $self, $stderr_output ) = @_;

#Processed 419675538 traces
#QC failed        0 traces

  my $log = slurp defined $stderr_output ? $stderr_output : \*STDIN;
  if($log=~/^Processed \s+ (\d+) \s+ traces$/smx) {$self->num_total_reads($1);}
  if($log=~/^(?:QC[ ]failed|Removed) \s+ (\d+) \s+ traces$/smx) {$self->num_spatial_filter_fail_reads($1);}

  return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

    npg_qc::autoqc::results::spatial_filter

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=head2 parse_output - parse the spatial_filter stderr output and store relevant data in result object

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item npg_qc::autoqc::results::result

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David K. Jackson E<lt>david.jackson@sanger.ac.ukE<gt><gt>

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
