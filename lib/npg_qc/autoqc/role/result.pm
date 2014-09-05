package npg_qc::autoqc::role::result;

use Moose::Role;
use Carp;
use File::Spec::Functions qw(catfile);
use JSON;
use MooseX::Storage;
use Readonly;
use List::MoreUtils qw/none/;

with Storage( 'traits' => ['OnlyWhenBuilt'],
              'format' => 'JSON',
              'io'     => 'File' ), 'npg_qc::autoqc::role::rpt_key';

our $VERSION = '0';

Readonly::Array my @SEARCH_PARAMETERS => qw/ position class_name check_name id_run tag_index /;

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::autoqc::role::result

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 class_name

Name of the class that did the check

=cut
sub class_name {
    my $self = shift;
    my ($ref) = (ref $self) =~ /(\w*)$/smx;
    if ($ref =~ /^[[:upper:]]/xms) {
        if ($ref eq 'QXYield') {
	    $ref = 'qX_yield';
        } else {
            $ref =~ s/([[:lower:]])([[:upper:]])/$1_$2/gmxs;
            $ref = lc $ref;
	}
    }
    return $ref;
}

=head2 class_names

Converts autoqc package name or serialized class name to autoqc and DBIx result class names

=cut
sub class_names {
    my ($self, $name) = @_;
    if (!$self) {
      croak 'No arguments to class_names';
    }
    $name ||= (ref $self || $self);
    my ($class_name) = $name =~ /(\w+)(?:-\d+)?$/mxs;
    ##no critic (ProhibitParensWithBuiltins)
    my $dbix_class_name = join q[], map {ucfirst $_} split(/_/sm, $class_name);
    ##use critic
    return ($class_name, $dbix_class_name);
}

=head2 package_name

Name of the package that did the check

=cut
sub package_name {
    my $self = shift;
    return (ref $self);
}


=head2 check_name

Human readable check name

=cut
sub check_name {
    my $self = shift;
    my $name = $self->class_name;
    $name =~ s/sequence_error/sequence mismatch/xms;
    if ($self->can(q[sequence_type]) && $self->sequence_type) {
        $name .= q[ ] . $self->sequence_type;
    }
    $name =~ s/_/ /gsmx;
    return $name;
}

=head2 equals_byvalue

Determines whether the values of the attributes in the object are as listed in the argument hash. 
Takes a reference to a hash where keys are the names of the attributes and values are expected values. 
Returns true if all values are as expected, otherwise returns false.
Supports comparison on the following attributes:
  id_run, position, tag_index, check_name, class_name.

 my $r = npg_qc::autoqc::results::result->new({id_run => 222, position => 2, path => q[my_path]});
 $r->equals_byvalue({id_run => 222, position => 2,}); #returns 1
 $r->equals_byvalue({id_run => 222, position => 1,}); #returns 0
 $r->equals_byvalue({id_run => 222,});                #returns 1

=cut
sub equals_byvalue {
    my ($self, $h) = @_;
    if (!$h) {
        croak q[Parameters hash shoudl be given];
    }
    my @keys =keys %{$h};
    if (!@keys) {
        croak q[No parameters for comparison];
    }

    foreach my $key (@keys) {
        if (none { $_ eq $key } @SEARCH_PARAMETERS) {
            croak qq[Value of the $key attribute cannot be compared. Valid attributes: ] . join q[, ], @SEARCH_PARAMETERS;
	}
        if ($key eq q[tag_index]) {
            if ( !$self->can($key) || (!defined $h->{$key} && defined $self->$key) ||
                    (defined $h->{$key} && !defined $self->$key) ) {
                return 0;
            }
            if (!defined $h->{$key} && !defined $self->$key) { next; }
	}
        if ($self->$key ne $h->{$key}) {return 0;}
    }
    return 1;
}

=head2 add_comment

Appends a comment to a string of comments
  
=cut
sub add_comment {
    my ($self, $comment) = @_;
    if (!$comment) {return 1;}
    if (!$self->comments) {
        $self->comments($comment);
    } else {
        $self->comments($self->comments . q[ ] . $comment);
    }
    return 1;
}

=head2 to_string

Human friendly object description
  
=cut
sub to_string {
    my ($self) = @_;
    my $s = ref $self;
    $s .= q[ object for id_run ] . $self->id_run . q[ position ] . $self->position;
    if ($self->can('tag_index') and defined $self->tag_index) {
        $s .= q[ tag index ] . $self->tag_index;
    }
    return $s;
}

=head2 filename4serialization

Filename that should be used to write json serialization of this object to

=cut
sub filename4serialization {
    my $self = shift;
    return sprintf q[%s_%s%s%s.%s.%s],
                   $self->id_run,
                   $self->position,
                   $self->tag_label(),
                   $self->can(q[sequence_type]) && $self->sequence_type ? q[_] . $self->sequence_type : q[],
                   $self->class_name,
                   q[json];
}

=head2 write2file

Serializes the object as a json string to a folder given by the destination argument.
The output file name follows the pattern idrun_position.check_name.extension.

=cut
sub write2file {
    my ($self, $destination) = @_;

    $destination = catfile($destination, $self->filename4serialization());
    open my $fh, q[>], $destination or croak "Cannot open $destination for writing";
    ##no critic (RequireBracedFileHandleWithPrint) 
    print $fh $self->freeze() or croak "Cannot write to $destination";
    close $fh or carp "Cannot close a handle to $destination";
    return 1;
}

around 'store' => sub { #use filename4serialization for default file name if none or directory is passed as argument
    my ($orig, $self, $file) = @_;
    $file = (not defined $file) ? $self->filename4serialization() :
            -d $file            ? catfile($file,$self->filename4serialization()) :
                                  $file;
    return $self->$orig($file);
};

=head2 json

Serialization of this object to JSON.

=cut
sub json {
    my $self = shift;
    my $package_name = ref $self;
    if (!$package_name) {
      croak '"json" method should be called on an object instance';
    }
    if ($package_name =~ /Schema/xms) {
        my $h = {'__CLASS__' => $package_name};
        foreach my $column ($self->result_source->columns()) {
            $h->{$column} = $self->$column;
        }
        return to_json($h);
    }
    return $self->freeze();
}

1;
__END__


=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item MooseX::Storage

=item Carp

=item File::Spec::Functions

=item JSON

=item List::MoreUtils

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Genome Research Limited

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
