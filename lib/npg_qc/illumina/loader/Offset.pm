#########
# Author:        gq1
# Created:       2010-02-19
#
package npg_qc::illumina::loader::Offset;

use Moose;
use Carp;
use English qw{-no_match_vars};
use Readonly;
use Perl6::Slurp;

extends qw{npg_qc::illumina::loader::base};

our $VERSION = '0';

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::illumina::loader::Offset

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 file_name

offset file name
 
=cut
has 'file_name'    => (isa           => q{Str},
                       is            => q{rw},
                       lazy_build    => 1,
                       documentation => q{offset file name},
                      );

sub _build_file_name {
  my $self = shift;

  return $self->intensity_path().q{/Offsets/offsets.txt}
}

=head2 run

=cut

sub run {
  my ($self) = @_;

  my $offset_file_name = $self->file_name();
  if(! -e $offset_file_name){
    $self->mlog("There is no offset file available\n$offset_file_name");
    return;
  }
  my $transaction = sub { $self->_process_offset($offset_file_name) };
  $self->schema->txn_do($transaction);
  return;
}

sub _process_offset {
    my ($self, $file_url) = @_;

    my $id_run = $self->id_run();

    my @lines    = split /\n/xms, slurp $file_url;

    foreach my $line (@lines) {

      my @temp = split q{ }, $line;
      my $position = shift @temp;
      my $tile = shift @temp;
      my $cycle = shift  @temp;
      my $image = shift  @temp;
      my $x = shift  @temp;
      my $y = shift  @temp;
      my $fields_db = {id_run   => $id_run,
                       lane     => $position,
                       tile     => $tile,
                       cycle    => $cycle,
                       image    => $image,
                       x        => $x,
                       y        => $y,
                    };
       $self->schema->resultset('Offset')->update_or_create( $fields_db );
    }

    return 1;
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

=item Carp

=item English -no_match_vars

=item Readonly

=item Perl6::Slurp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

$Author: gq1 $

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
