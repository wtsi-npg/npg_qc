#########
# Author:        gq1
# Created:       2010-02-19
#
package npg_qc::illumina::loader::Matrix;

use Moose;
use namespace::autoclean;
use Carp;
use English qw{-no_match_vars};
use Readonly;
use Perl6::Slurp;

extends qw{npg_qc::illumina::loader::base};

our $VERSION = '0';

Readonly::Scalar our $BASE_ORDER => [ qw(A C T G) ];
Readonly::Scalar our $SECOND_READ_NUMER_INDEX_RUN => 3;

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::illumina::loader::Matrix

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 file_list

matrix file list
 
=cut
has 'file_list'    => (isa           => q{ArrayRef},
                       is            => q{rw},
                       lazy_build    => 1,
                       documentation => q{matrix file name list},
                      );

sub _build_file_list {
  my $self = shift;

  my @file_list = ();

  my $folder_path = $self->bustard_path() . q{/Matrix};
  opendir my $dh, $folder_path or ( carp "Cannot open $folder_path" && return \@file_list );
  @file_list = map { $folder_path.qq{/$_} } grep { /s_\d+_\d+_matrix[.]txt/mxs } sort readdir $dh;
  closedir $dh or croak qq(Cannot close $folder_path);

  return \@file_list;
}

=head2 config_xml_file

basecall config xml file name
 
=cut
has 'config_xml_file'    => (isa           => q{Str},
                             is            => q{ro},
                             lazy_build    => 1,
                             documentation => q{basecall config xml file name},
                            );
sub _build_config_xml_file {
   my $self = shift;

   return $self->bustard_path() . q{/config.xml};
}

=head2 _matrix_cylce_per_read

matrix cycle number per read
 
=cut
has '_matrix_cylce_per_read' => (isa           => q{HashRef},
                                 is            => q{ro},
                                 lazy_build    => 1,
                                 documentation => q{matrix cycle number per read},
                                );

sub _build__matrix_cylce_per_read {
   my $self = shift;

   my %matrix_cycle_per_read = ();
   my $config_file = $self->config_xml_file();

   if( -e $config_file ){

         my $xml_dom = $self->parser->parse_file( $config_file );
         my $matrix_list = $xml_dom->getElementsByTagName('Matrix');

         foreach my $matrix (@{$matrix_list}){

             my $cycle = $matrix->getElementsByTagName('Cycle')->[0]->textContent();
             my $read = $matrix->getElementsByTagName('Read')->[0]->textContent();
             if(!$cycle || !$read){
                croak "Matrix read and cycle number can not be found from config xml file $config_file";
             }else{

                $matrix_cycle_per_read{$read} = $cycle;
             }
         }
   }

   return \%matrix_cycle_per_read;
}

=head2 run

loads one run matrix data

=cut

sub run {
  my ($self) = @_;

  my $file_list = $self->file_list();
  $self->mlog('There are '.scalar @{$file_list}. ' files to process');

  my $transaction = sub {
    foreach my $matrix_file (@{$file_list}){
      $self->_process_matrix( $matrix_file );
    }
  };
  $self->schema->txn_do($transaction);
  return;
}

sub _process_matrix {
    my ($self, $file_url) = @_;

    my $id_run = $self->id_run();

    my $matrix_cylce_per_read = $self->_matrix_cylce_per_read();

    my ($position, $cycle_or_read) = $file_url =~ /s_(\d{1})_(\d+)_matrix[.]txt/xms;
    $cycle_or_read += 0;

    my $field_db = {id_run => $id_run,
                    lane   => $position,
                    cycle  => $cycle_or_read,
                   };

    my @lines    = split /\n/xms, slurp $file_url;

    my @base_list;
    my @values;
    my $cycle_number_in_filename;

    foreach my $line (@lines) {
      next if ($line =~ /\A\#/xms);
      if($line =~ /\A>/xms){
        push @base_list, substr $line, 2, 1;
        $cycle_number_in_filename = 1;
      }else{
         my @values_per_line = split /\s+/xms, $line;
         push @values, @values_per_line;
      }
    }

    if( ! (scalar @base_list) ){
        @base_list = @{$BASE_ORDER};
    }

    if(! $cycle_number_in_filename && scalar keys %{$matrix_cylce_per_read} > 0 ){

      $field_db->{cycle} = $matrix_cylce_per_read->{$cycle_or_read};
    }elsif (! $cycle_number_in_filename ){

         $cycle_or_read = $self->_second_cycle_number_by_read($cycle_or_read);
         $field_db->{cycle} = $cycle_or_read;
    }

    foreach my $base (@base_list) {

      $field_db->{base} = $base;
      $field_db->{red1} = shift @values;
      $field_db->{red2} = shift @values;
      $field_db->{green1} = shift @values;
      $field_db->{green2} = shift @values;

      $self->schema->resultset('FrequencyResponseMatrix')->update_or_create( $field_db );
    }

    return 1;
}

sub _second_cycle_number_by_read {
   my ($self, $read) = @_;

   if( $read == 1 ){

      my @range= $self->read1_cycle_range();
      return $range[0] + 1;
   }elsif( $read == $SECOND_READ_NUMER_INDEX_RUN || ($read == 2 && !$self->is_indexed())){

     my @range= $self->read2_cycle_range();
      return $range[0] + 1;
   }elsif($read == 2 && $self->is_indexed()){

      my @range = $self->indexing_cycle_range();
      return $range[0] + 1;
   }
   return;
}

no Moose;
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
