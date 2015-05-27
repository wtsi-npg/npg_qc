#########
# Author:        Marina Gourtovaia mg8@sanger.ac.uk
# Created:       3 February 2010
#

package npg_qc::autoqc::checks::gc_fraction;

use strict;
use warnings;
use Moose;
use Carp;
use English qw(-no_match_vars);
use Readonly;
use File::Spec::Functions qw(catfile);
use File::Basename;

use npg_tracking::util::abs_path qw(abs_path);
use npg_common::fastqcheck;
use npg_common::sequence::reference::base_count;

#########################################################
# 'extends' should prepend 'with' since the
# fields required by the npg_qc::autoqc::align::reference
# role are defined there; there is a bug in Moose::Role
#########################################################
extends qw(npg_qc::autoqc::checks::check);
with qw(npg_tracking::data::reference::find);


our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd RequireCheckingReturnValueOfEval ProhibitParensWithBuiltins)

=head1 NAME

npg_qc::autoqc::checks::gc_fraction

=head1 SYNOPSIS

Inherits from npg_qc::autoqc::checks::check. See description of attributes in the documentation for that module.
  my $check = npg_qc::autoqc::checks::gc_content->new(
          path => q[/staging/IL29/analysis/090721_IL29_3379/data], position => 1
                                                      );

=head1 DESCRIPTION

Calculates gc content for a sequence and evaluates this value against the gc content of the reference genome

=head1 SUBROUTINES/METHODS

=cut

Readonly::Scalar our $EXT                  => 'fastqcheck';
Readonly::Scalar our $HUNDRED              => 100;
Readonly::Scalar our $APP                  => q[npgqc];
Readonly::Scalar our $NA                   => -1;
Readonly::Scalar our $MAX_DELTA            => 20;



=head2 aligner

Overrides an attribute with the same name in npg_tracking::data::reference::find.
Defaults to te name of the application that will access the data, ie npgqc.

=cut
has '+aligner'          => ( default         => $APP, );


=head2 ref_base_count_path

A path to a file with base count for the relevant reference genome.
Does not include teh extension.

=cut
has 'ref_base_count_path' => (isa         => 'Maybe[Str]',
                              is          => 'ro',
                              required    => 0,
                              lazy_build  => 1,
                             );

has '+input_file_ext' => (default    => $EXT,);

sub _build_ref_base_count_path {
    my $self = shift;
    my @refs;
    eval {
        @refs = @{$self->refs()};
    };
    if ($EVAL_ERROR) {
        $self->result->add_comment(q[Error: reference cannot be retrieved; cannot run gc content check. ] . $EVAL_ERROR);
        return;
    }

    if ($self->messages->count) {
        $self->result->add_comment(join(q[ ], $self->messages->messages));
    }

    if (scalar @refs > 1) {
	$self->result->add_comment(q[multiple references found: ] . join(q[;], @refs));
        return;
    }

    if (scalar @refs == 0) {
        $self->result->add_comment(q[Failed to retrieve a reference.]);
        return;
    }
    return (pop @refs);
}


override 'execute'            => sub {

    my $self = shift;
    if(!super()) {return 1;}

    my @files = @{$self->input_files};
    my $short_fnames = $self->generate_filename_attr();

    my $ref_data_path;
    my $ref_gc_percent;
    if ($self->ref_base_count_path) {
        $ref_data_path = $self->ref_base_count_path . q[.json];
        if (-r $ref_data_path) {
            my $ref_base_count_hash =
     npg_common::sequence::reference::base_count->load($ref_data_path)->summary->{counts};
            $ref_gc_percent = $self->_gc_percent($ref_base_count_hash);
        }
    }

    $self->result->threshold_difference($MAX_DELTA);

    my $count = 0;
    my @apass = ($NA, $NA);
    my @prefix = qw/forward reverse/;

    foreach my $file (@files) {
        my $bc = npg_common::fastqcheck->new(fastqcheck_path => $file);
        my $base_count_hash = $bc->base_percentages();
        my $result_method = $prefix[$count] . q[_read_gc_percent];
        $self->result->$result_method($self->_gc_percent($base_count_hash));
        my $filename_method =  $prefix[$count] . q[_read_filename];
        $self->result->$filename_method($short_fnames->[$count]);

      if (defined $ref_gc_percent) {
          $apass[$count] = 0;
          if ( abs ($self->result->$result_method - $ref_gc_percent) < $MAX_DELTA ) {
              $apass[$count] = 1;
          }
      }
      $count++;
    }

    if (defined $ref_gc_percent) {
        $self->result->ref_gc_percent($ref_gc_percent);
    }
    if (defined $self->ref_base_count_path) {
        my ($filename, $directories, $suffix) = fileparse($self->ref_base_count_path);
        $self->result->ref_count_path(abs_path($directories), $filename);
    }

    my $pass = $self->overall_pass(\@apass, $count);
    if ($pass != $NA) { $self->result->pass($pass); }

    return 1;
};


sub _gc_percent {

    my ($self, $base_count_hash) = @_;
    my $gc_percent = 0;
    if (exists $base_count_hash->{G}) {
        $gc_percent = $base_count_hash->{G};
    }
    if (exists $base_count_hash->{C}) {
        $gc_percent += $base_count_hash->{C};
    }
    my $total_percent = $gc_percent;
    if (exists $base_count_hash->{A}) {
        $total_percent += $base_count_hash->{A};
    }
    if (exists $base_count_hash->{T}) {
        $total_percent += $base_count_hash->{T};
    }

    my $result = 0;
    if ($total_percent != 0) {
        $result = $gc_percent/$total_percent * $HUNDRED;
    }

    return $result;
}


no Moose;

1;
__END__


=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Carp

=item English

=item Readonly

=item Moose

=item File::Spec::Functions

=item File::Basename

=item npg_tracking::util::abs_path

=item npg_tracking::data::reference::find

=item npg_common::sequence::reference::base_count

=item npg_common::fastqcheck

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Marina Gourtovaia

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
