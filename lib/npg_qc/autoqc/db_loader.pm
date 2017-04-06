package npg_qc::autoqc::db_loader;

use Moose;
use namespace::autoclean;
use Class::Load qw/load_class/;
use Carp;
use JSON;
use Try::Tiny;
use Perl6::Slurp;
use List::MoreUtils qw/any none/;
use Readonly;

use npg_tracking::util::types;
use npg_qc::Schema;
use npg_qc::autoqc::role::result;

with qw/MooseX::Getopt/;

our $VERSION = '0';

Readonly::Scalar my $CLASS_FIELD => q[__CLASS__];

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

has '_schema_sources' => ( isa        => 'ArrayRef',
                           is         => 'ro',
                           required   => 0,
                           lazy_build => 1,
                         );
sub _build__schema_sources {
  my $self = shift;
  return [$self->schema()->sources()];
}
sub _schema_has_source {
  my ($self, $source_name) = @_;
  return any { $_ eq $source_name } @{$self->_schema_sources()};
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
      # Force scalar context since json file can contain multiple strings
      my $json = slurp($json_file);
      $count += $self->_json2db($json, $json_file);
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
  my ($self, $json, $json_file) = @_;

  if (!$json) {
    croak 'JSON string representation of the object is missing';
  }

  my $count = 0;
  try {
    my $values = decode_json($json);
    my $class_name = delete $values->{$CLASS_FIELD};
    if ($class_name) {
      ($class_name, my $dbix_class_name) =
        npg_qc::autoqc::role::result->class_names($class_name);
      if ($dbix_class_name && $self->_pass_filter($values, $class_name)) {
        if ($self->_schema_has_source($dbix_class_name)) {
          my $module = 'npg_qc::autoqc::results::' . $class_name;
          load_class($module);
          my $obj = $module->thaw($json);

          if ($class_name eq 'bam_flagstats') {
            $values = decode_json($obj->freeze());
          }
          my $composition_key = 'id_seq_composition';
          if ( $obj->can('composition') && $obj->can('composition_digest') &&
              $self->schema->source($dbix_class_name)->has_column($composition_key) ) {
            $values->{$composition_key} = $self->_ensure_composition_exists($obj);
          }
          # Load the main object
          $count = $self->_values2db($dbix_class_name, $values);
        }
      }
    }
  } catch {
    my $j =  $json_file || $json;
    $self->_log("Attempted to load $j");
    croak $_;
  };
  my $m = $count ? 'Loaded' : 'Skipped';
  $self->_log(join q[ ], $m, $json_file || q[json string]);

  return $count;
}

sub _ensure_composition_exists {
  my ($self, $obj) = @_;

  my $num_components = $obj->composition->num_components;
  my $composition_row = $self->schema->resultset('SeqComposition')
    ->find_or_new({ 'digest' => $obj->composition_digest,
                    'size'   => $num_components, });
  my $composition_exists = 1;
  if (!$composition_row->in_storage()) {
    $composition_row->insert();
    $composition_exists = 0;
  }
  my $pk = $composition_row->id_seq_composition;

  if (!$composition_exists) {

    my $component_rs   = $self->schema->resultset('SeqComponent');
    my $comcom_rs      = $self->schema->resultset('SeqComponentComposition');

    foreach  my $c ($obj->composition->components_list()) {
      my $values = decode_json($c->freeze());
      $values->{'digest'} = $c->digest();
      my $row = $component_rs->find_or_create($values);
      # Whether the component existed or not, we have to create a new
      # composition membership record for it.
      $values = {
        'id_seq_composition' => $pk,
        'id_seq_component'   => $row->id_seq_component,
        'size'               => $num_components,
      };
      $comcom_rs->create($values);
    }
  }

  return $pk;
}

sub _values2db {
  my ($self, $dbix_class_name, $values) = @_;

  my $iscurrent_column_name      = 'iscurrent';
  my $composition_fk_column_name = 'id_seq_composition';
  my $count = 0;
  my $rs = $self->schema->resultset($dbix_class_name);
  my $result_class = $rs->result_class;
  $self->_exclude_nondb_attrs($values, $result_class->columns());

  my $found;
  if ($result_class->has_column($iscurrent_column_name)) {
    my $fk_value = $values->{$composition_fk_column_name};
    if ($fk_value) {
      $rs->search({$composition_fk_column_name => $fk_value})
         ->update({$iscurrent_column_name => 0});
    }
  } else {
    $rs->deflate_unique_key_components($values);
    $found = $rs->find($values);
  }

  if ($found) {
    if ($self->update) {
      # We need to convert non-scalar values (hashes or arrays) to scalars
      $found->set_inflated_columns($values)->update();
      $count++;
    }
  } else {
    # See comment above
    $rs->new_result($values)->set_inflated_columns($values)->insert();
    $count++;
  }

  return $count;
}

sub _exclude_nondb_attrs {
  my ($self, $values, @columns) = @_;

  foreach my $key ( keys %{$values} ) {
    if (none {$key eq $_} @columns) {
      delete $values->{$key};
      if ($key ne $CLASS_FIELD && $key ne 'composition') {
        $self->_log("Not loading field '$key'");
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

  if (@{$self->id_run} || @{$self->lane}) {
    my $id_run   = $values->{'id_run'};
    my $position = $values->{'position'};
    if ( !$id_run  && $values->{'composition'} ) {
      my $composition = $values->{'composition'};
      if (ref $composition eq 'npg_tracking::glossary::composition' &&
          $composition->num_components == 1) {
        my $component = $composition->get_component(0);
        $id_run   = $component->id_run;
        $position = $component->position;
      }
    }

    if ( @{$self->id_run} && $id_run ) {
      if ( none {$_ == $id_run} @{$self->id_run} ) {
        return 0;
      }
    }
    if ( @{$self->lane} && $position ) {
      if ( none {$_ == $position} @{$self->lane} ) {
        return 0;
      }
    }
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

=head2 path

  Array with directory names from where json files have to be loaded;
  redandant if json_files is defined by the caller.

=head2 json_files

  Array of json files, optional attribute.

=head2 id_run

  An array of run ids to load, optional attribute, acts as a filter.

=head2 lane

  An array of lane numbers to load, optional attribute, acts as a filter.

=head2 check

  An array of autoqc check names to load, optional attribute.

=head2 load

  Method that performs loading of json files to a database.

=head2 verbose

  A boolean attribute, switches logging on/off, true by default.

=head2 update

  A boolean attribute, true by default, switches on/off updates of existing
  results. If false, only new results are inserted.

=head2 schema

  DBIx connection to the npg_qc database.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Class::Load

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

Copyright (C) 2016 GRL

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
