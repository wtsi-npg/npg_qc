package npg_qc::autoqc::db_loader;

use Moose;
use Class::Load;
use namespace::autoclean;
use Carp;
use JSON;
use Try::Tiny;
use Perl6::Slurp;
use List::MoreUtils qw/none/;
use Readonly;

use npg_qc::Schema;
use npg_tracking::util::types;
use npg_qc::autoqc::role::result;

with qw/MooseX::Getopt/;

our $VERSION = '0';

Readonly::Scalar my $CLASS_FIELD            => q[__CLASS__];
Readonly::Scalar my $RELATED_DATA_ACCESSOR_NAME => q[related_data];

has 'path'   =>  ( is          => 'ro',
                   isa         => 'ArrayRef[Str]',
                   required    => 0,
                   default     => sub {[]},
                 );

has 'id_run'  => ( is          => 'ro',
                   isa         => 'ArrayRef[NpgTrackingRunId]',
                   required    => 0,
                   default     => sub {[]},
                 );

has 'lane'    => ( is          => 'ro',
                   isa         => 'ArrayRef[NpgTrackingLaneNumber]',
                   required    => 0,
                   default     => sub {[]},
                 );

has 'check'   => ( is          => 'ro',
                   isa         => 'ArrayRef[Str]',
                   required    => 0,
                   default     => sub {[]},
                 );

has 'update'  => ( is       => 'ro',
                   isa      => 'Bool',
                   required => 0,
                   default  => 1,
                 );

has 'json_file' => ( is          => 'ro',
                     isa         => 'ArrayRef',
                     required    => 0,
                     lazy_build  => 1,
                   );
sub _build_json_file {
  my $self = shift;
  if (!scalar @{$self->path}) {
    croak q[path should be supplied];
  }
  my @files = ();
  foreach my $path (@{$self->path}) {
    if (!-d $path) {
      $self->_log(qq[$path is not a directory, skipping]);
      next;
    }
    push @files, glob File::Spec->catfile($path, q[*.json]);
  }
  return \@files;
}

has 'schema' =>    ( isa        => 'npg_qc::Schema',
                     metaclass  => 'NoGetopt',
                     is         => 'ro',
                     required   => 0,
                     lazy_build => 1,
                    );
sub _build_schema {
  return npg_qc::Schema->connect();
}

has 'verbose' =>    ( is       => 'ro',
                      isa      => 'Bool',
                      required => 0,
                      default  => 1,
                    );

sub load{
  my $self = shift;

  my $transaction = sub {
    my $count = 0;
    foreach my $json_file (@{$self->json_file}) {
      $count += $self->_json2db($json_file);
    }
    return $count;
  };

  my $num_loaded = 0;
  try {
    $num_loaded = $self->schema->txn_do($transaction);
  } catch {
    my $m = "Loading aborted, transaction has rolled back: $_";
    $self->_log($m);
    croak $m;
  };
  $self->_log("$num_loaded json files have been loaded");

  return $num_loaded;
}

sub _json2db{
  my ($self, $json_file) = @_;

  my $count = 0;
  try {
    my $values = decode_json(slurp $json_file);
    my $class_name = delete $values->{$CLASS_FIELD};
    if ($class_name) {
      ($class_name, my $dbix_class_name) =
        npg_qc::autoqc::role::result->class_names($class_name);

      if ($dbix_class_name && $self->_pass_filter($values, $class_name)) {

        my $module = 'npg_qc::autoqc::results::' . $class_name;
        Class::Load::load_class($module);
        my $instance = $module->load($json_file);
        if ($module eq 'npg_qc::autoqc::results::bam_flagstats') {
          $values = decode_json($instance->freeze());
        }
        my $rs = $self->schema->resultset($dbix_class_name);
        my $result_class = $rs->result_class;

        $self->_exclude_nondb_attrs($json_file, $values, $result_class->columns());
        $result_class->deflate_unique_key_components($values);

        my $db_result;
        if ($self->update) {
          $db_result = $rs->find_or_new($values)->set_inflated_columns($values)->update_or_insert();
          $count = 1;
        } else {
          if (!$rs->find($values)) {
            $db_result = $rs->new($values)->set_inflated_columns($values)->insert();
            $count = 1;
          }
        }

        if ($db_result && $instance->can($RELATED_DATA_ACCESSOR_NAME)) {
          foreach my $related_values ( @{$instance->$RELATED_DATA_ACCESSOR_NAME} ) {
            # We can get the relationship name from the DBIx object itself.
            # However, then we cannot have multiple child tables. For bam_flagstats
            # we are planning to have two.
            my $relationship_name = delete $related_values->{'relationship_name'};
            if ($relationship_name) {
              $self->_log("Creating related record for $relationship_name");
              $db_result->update_or_create_related($relationship_name, $related_values);
            }
          }
        }
      }
    }
  } catch {
    $self->_log("Attempted to load $json_file");
    croak $_;
  };
  my $m = $count ? 'Loaded' : 'Skipped';
  $self->_log(join q[ ], $m, $json_file);
  return $count;
}

sub _exclude_nondb_attrs {
  my ($self, $json_file, $values, @columns) = @_;

  foreach my $key ( keys %{$values} ) {
    if (none {$key eq $_} @columns) {
      delete $values->{$key};
      if ($key ne $CLASS_FIELD) {
        $self->_log("$json_file: not loading field '$key'");
      }
    }
  }
  return;
}

sub _pass_filter {
  my ($self, $values, $class_name) = @_;
  if (!$values || !(ref $values) || ref $values ne 'HASH') {
    croak 'Need hashed values to do filtering';
  }
  if (!$class_name) {
    croak 'Need class name to do filtering';
  }
  if ( scalar @{$self->check} && none {$_ eq $class_name} @{$self->check}) {
    return 0;
  }
  if ( scalar @{$self->id_run} && none {$_ == $values->{'id_run'}} @{$self->id_run}) {
    return 0;
  }
  if ( scalar @{$self->lane} && none {$_ == $values->{'position'}} @{$self->lane}) {
    return 0;
  }
  return 1;
}

sub _log {
  my ($self, $m) = @_;
  if ($self->verbose) {
    warn "$m\n";
  }
  return;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

npg_qc::autoqc::db_loader

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 path - a reference to an array with directory names from where json files have to be loaded;
              redandant if json_files is defined by the caller

=head2 id_run - an array of run ids to load, optional attribute

=head2 json_files - a reference to a list of json files, optional attribute

=head2 lane - an array of lane numbers to load, optional attribute

=head2 check - an array of autoqc check names to load, optional attribute

=head2 load - performs loading of json files to a database

=head2 verbose - boolean switching logging on/off, on by default

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Class::Load

=item namespace::autoclean

=item MooseX::Getopt

=item Carp

=item JSON

=item Try::Tiny

=item Perl6::Slurp

=item List::MoreUtils

=item Readonly

=item npg_qc::Schema

=item npg_tracking::util::types

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL

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

=cut
