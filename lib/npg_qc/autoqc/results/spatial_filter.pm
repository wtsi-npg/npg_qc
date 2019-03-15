package npg_qc::autoqc::results::spatial_filter;

use Moose;
use namespace::autoclean;
use Carp;
use File::Slurp;

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
  my ( $self, $files ) = @_;

# expected format: "<rpt> Processed 943540734     Failed 4338894 traces"

  # this assumes the check is only run at lane level so id_run and position will be unique
  my $id_run = $self->composition->get_component(0)->id_run;
  my $position = $self->composition->get_component(0)->position;
  my $key = q{Lane[ ]}. $position;

  my $num_total_reads = 0;
  my $num_spatial_filter_fail_reads = 0;
  my $count = 0;
  for my $file (@{$files}) {
    my @contents = read_file $file || croak "Unable to read file $file";

    for my $line (@contents) {
      my ($total, $fail) = ($line =~ /^$key[^\t]* \t Processed \s+ (\d+) \s+ Failed \s+ (\d+) \s+ traces$/smx);

      if(not defined $total or not defined $fail) { next; }

      $count++;
      $num_total_reads += $total;
      $num_spatial_filter_fail_reads += $fail;
    }
  }
  # values should be undefined if there is no data in the output
  $self->num_total_reads($count ? $num_total_reads : undef);
  $self->num_spatial_filter_fail_reads($count ? $num_spatial_filter_fail_reads : undef);
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
