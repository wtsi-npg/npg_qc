#########
# Author:        gq1
# Created:       2010-02-19
#
package npg_qc::illumina::loader::Signal_Mean;

use Moose;
use namespace::autoclean;
use Carp;
use English qw{-no_match_vars};
use Readonly;
use Perl6::Slurp;

extends qw{npg_qc::illumina::loader::base};

our $VERSION = '0';

Readonly::Scalar our $VALUE_FOR_DATA_MINING_EFFICIENCY => -1;

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::illumina::loader::Signal_Mean

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 file_name

signal mean test file name
 
=cut
has 'file_name'    => (isa           => q{Str},
                       is            => q{rw},
                       lazy_build    => 1,
                       documentation => q{file name for signal mean text file},
                      );

sub _build_file_name {
  my $self = shift;
  return $self->bustard_path().q{/Signal_Means.txt};
}

=head2 run

loads one run data for signal mean

=cut

sub run {
  my ($self) = @_;

  my $signal_mean_file = $self->file_name();
  if(! -e $signal_mean_file){
    $self->mlog("Signal mean file not exists!\n$signal_mean_file");
    return 1;
  }

  my $file_content = slurp $signal_mean_file;

  my @lines  = split /\n/xms, $file_content;
  my @fields = qw(position cycle all_a all_c all_g all_t call_a call_c call_g call_t base_a base_c base_g base_t);

  my $transaction = sub {
    foreach my $line (@lines) {
      next if ($line =~ /\A\#/xms);

      my @values_per_lane_cycle = split q{ }, $line;
      my %values_hash = ();
      @values_hash{@fields} = @values_per_lane_cycle;
      $values_hash{id_run} = $self->id_run();
      $self->schema->resultset('SignalMean')->update_or_create( %values_hash );
    }
  };
  $self->schema->txn_do($transaction);

  return 1;
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

=item Carp

=item English -no_match_vars

=item Readonly

=item Perl6::Slurp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2009 Guoying Qi (gq1@sanger.ac.uk)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
