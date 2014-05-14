#########
# Author:        Marina Gourtovaia mg8@sanger.ac.uk
# Maintainer:    $Author$
# Created:       29 July 2009
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

package npg_qc::autoqc::autoqc;

use strict;
use warnings;
use Moose;
use MooseX::ClassAttribute;
use Carp;
use English qw(-no_match_vars);
use Readonly;
use File::Spec;
use List::Util qw(first);
use Module::Pluggable::Object;

use npg_tracking::util::types;
use npg_qc::autoqc::checks::check;

with  qw / npg_tracking::illumina::run::short_info
           npg_tracking::illumina::run::folder
           MooseX::Getopt
        /;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mxs; $r; };
## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::autoqc::autoqc

=head1 VERSION

$Revision$

=head1 SYNOPSIS

  my $autoqc = npg_qc::autoqc::autoqc->new(archive_path=>q[/staging/IL29/analysis/123456_IL2_2222/Data/Intensities/Bustard-2009-10-01/GERALD-2009-10-01/archive], position=>1, check=>q[insert_size]);
  $autoqc->run();
  my $checks = npg_qc::autoqc::autoqc->list_all_checks();

=head1 DESCRIPTION

A wrapper around autoqc lib.

=head1 SUBROUTINES/METHODS

=cut


Readonly::Array  my @NON_RUNNABLE_CHECKS => qw(tag_decode_stats split_stats bam_flagstats);
Readonly::Scalar my $CHECKS_NAMESPACE    => q[npg_qc::autoqc::checks];
Readonly::Scalar my $NO_TAG_INDEX        => -1;

=head2 checks_list

Class Attribute. Returns a ref to a list of attributes that are included into
the output of a check.

=cut
class_has 'checks_list' => (isa        => 'ArrayRef',
                            is         => 'ro',
                            required   => 0,
                            lazy_build => 1,
		          );
sub _build_checks_list {

    my @classes = Module::Pluggable::Object->new(
                          require     => 0,
                          search_path => $CHECKS_NAMESPACE,
                          except      => $CHECKS_NAMESPACE . q[::check],
                                                )->plugins;

    my @class_names = ();
    foreach my $class (@classes) {
        my @names = split /:/smx , $class;
        push @class_names, (pop @names);
    }
    @class_names = sort @class_names;
    push @class_names, @NON_RUNNABLE_CHECKS;
    return \@class_names;
}


=head2 tag_index

Tag index for a plex, does not have to be set.

=cut
has 'tag_index'    => (isa       => 'Int',
                       is        => 'ro',
                       required  => 0,
                       documentation => 'tag index, an integer betwee 0 and some large number, see npg_tracking::glossary::tag',
                      );


=head2 check

The name of the check to perform.

=cut
has 'check'    => (   isa      => 'Str',
                      is       => 'ro',
                      required => 1,
                      documentation => 'QC check name, one of returned by the check_list methods',
                      trigger  => \&_set_check_name,
                  );
sub _set_check_name {
    my ($self, $name) = @_;
    my @values = grep { /^$name$/sxm } @{$self->checks_list};
    if (@values == 0) {
        croak qq[Invalid check name $name, please choose a name from the list '] . join(q[ ], @{$self->checks_list}) . q['];
    }
}


=head2 position

Lane number.

=cut
has 'position' => (   isa      => 'NpgTrackingLaneNumber',
                      is       => 'ro',
                      required => 1,
                      documentation => 'Lane (position) number, an integer from 1 to 8 inclusive.',
                  );

=head2 repository

An absolute path to the current reference repository.

=cut
has 'repository'       => (isa =>'Str', is => 'ro', required  => 0,
                           documentation => 'Path to teh directory with ref repository and adapters',);
has 'reference_genome' => ( isa => 'Str', is => 'ro', required => 0,
                            documentation => 'Reference genome as defined in LIMS objects.',);
has 'species'          => ( isa => 'Str', is => 'ro', required => 0,
                            documentation => 'Species name as used in the reference repository. No synonyms please.',);
has 'strain'           => ( isa => 'Str', is => 'ro', required => 0,
                            documentation => 'Strain as used in the reference repository.',);
has 'sequence_type'    => ( isa => 'Str', is => 'ro', required => 0,
                            documentation => 'Sequence type as phix for spiked phix or similar.',);


=head2 qc_in

Path to a directory where the fastq and similar files for the check are found

=cut
has 'qc_in'       => (isa       => 'Str',
                      is        => 'ro',
                      required  => 0,
                      predicate => '_has_qc_in',
                      writer    => '_write_qc_in',
                      documentation => 'Path to a directory where the fastq and similar files for the check are found.',
                     );

=head2 file_type

Type of input file (fastq or bam).

=cut
has 'file_type'   => (isa       => 'Str',
                      is        => 'ro',
                      required  => 0,
                      documentation => 'Type of input file (fastq or bam).',
                     );

=head2 qc_out

Path to a directory where the results should be written to

=cut
has 'qc_out'      => (isa       => 'Str',
                      is        => 'ro',
                      required  => 0,
                      predicate => '_has_qc_out',
                      writer    => '_write_qc_out',
                      documentation => 'Path to a directory where the results should be written to.',
                     );


sub _build_run_folder {
    my ($self) = @_;
    return first {$_ ne q()} reverse File::Spec->splitdir($self->runfolder_path);
}

=head2 BUILD

build method

=cut

sub BUILD {
    my $self = shift;

    if ($self->_has_qc_in) {
        if (!$self->_has_qc_out) {
            $self->_write_qc_out($self->qc_in);
        }
    } else {
        if ($self->check() eq 'spatial_filter') {
            $self->_write_qc_in('/dev/stdin'); #horrid - need to rethink this object and bin/qc
        } elsif (defined $self->tag_index) {
            $self->_write_qc_in($self->lane_archive_path($self->position));
	} else {
            $self->_write_qc_in($self->archive_path);
        }
	if (!$self->_has_qc_out) {
            if (defined $self->tag_index) {
                $self->_write_qc_out($self->lane_qc_path($self->position));
            } else {
                $self->_write_qc_out($self->qc_path);
	    }
	}
    }
    if (!-R $self->qc_in) {
        croak q[Input qc directory ] . $self->qc_in . q[ does not exist or is not readable];
    }
    if (!-W $self->qc_out) {
        croak q[Output qc directory ] . $self->qc_out . q[ does not exist or is not writable];
    }
    return;
}

sub _tag_index_is_set {
    my $self = shift;
    return defined $self->tag_index;
}

sub _create_test_object {
    my $self = shift;

    my $pkg = $CHECKS_NAMESPACE . q[::] . $self->check;
    Class::MOP::load_class($pkg);
    my $init = {
                path      => $self->qc_in,
                position  => $self->position,
                id_run    => $self->id_run,
	       };

    my @attrs = qw/tag_index repository reference_genome species strain sequence_type file_type/;
    foreach my $attr_name (@attrs) {
        if ($attr_name eq q[tag_index] ) {
            if (defined $self->$attr_name) {
                $init->{$attr_name} = $self->$attr_name;
	    }
        } else {
            if ($self->$attr_name) {
                $init->{$attr_name} = $self->$attr_name;
	    }
	}
    }
    return $pkg->new($init);
}


=head2 run

Creates an object that can perform the requested test, calls test execution and writes out test results to the output folder.

=cut
sub run {

    my $self = shift;

    if (!-e $self->qc_out) {
        croak q[Destination directory for qc results ] . $self->qc_out . q[ does not exist];
    }

    my $check = $self->_create_test_object();
    $check->execute();
    $check->result->write2file($self->qc_out);

    return 1;
}


=head2 can_run

Checks whether a check can be executed for a particular run.
If there are any problems with this test, returns 1.

=cut
sub can_run {

    my $self = shift;
    my $check = $self->_create_test_object();
    return $check->can_run;
}

no Moose;
no MooseX::ClassAttribute;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::ClassAttribute

=item File::Spec

=item Carp

=item English -no_match_vars

=item Readonly

=item List::Util

=item Module::Pluggable::Object

=item npg_tracking::illumina::run::short_info

=item npg_tracking::illumina::run::folder

=item npg_tracking::util::types

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

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
