package npg_qc::autoqc::checks::meta;

use Moose;
use namespace::autoclean;
use Carp;
use Readonly;
use List::MoreUtils qw/all any uniq/;
use English qw/-no_match_vars/;
use DateTime;

use WTSI::DNAP::Utilities::Timestamp qw/create_current_timestamp/;
use st::api::lims;
use npg_qc::autoqc::qc_store;
use npg_qc::Schema::Mqc::OutcomeDict;

extends 'npg_qc::autoqc::checks::check';
with 'npg_tracking::util::pipeline_config';

our $VERSION = '0';

Readonly::Scalar my $CONJUNCTION_OP => q[and];
Readonly::Scalar my $DISJUNCTION_OP => q[or];

Readonly::Scalar my $ROBO_KEY         => q[robo_qc];
Readonly::Scalar my $LIBRARY_TYPE_KEY => q[library_type];
Readonly::Scalar my $ACCEPTANCE_CRITERIA_KEY => q[acceptance_criteria];

Readonly::Scalar my $TIMESTAMP_FORMAT_WOFFSET => q[%Y-%m-%dT%T%z];

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::autoqc::checks::meta

=head1 SYNOPSIS

  my $check = npg_qc::autoqc::checks::meta->new(qc_in => 'dir_in');
  $check->execute();

=head1 DESCRIPTION

=head2 Overview

This checks evaluates the results of other autoqc checks
against a pre-defined set of criteria.

If data product acceptance criteria for a project and the
product's library type are defined, it is possible to introduce
a degree of automation into the manual QC process. To provide
interoperability with the API supporting the manual QC process,
the outcome of the evaluation performed by this check is recorded
not only as a simple pass or fail as in other autoqc checks, but
also as one of valid manual QC outcomes. A valid manual QC outcome
is one of the values from the library qc outcomes dictionary
(mqc_library_outcome_dict table of the npg_qc database), ie one
of 'Accepted', 'Rejected' or 'Undecided' outcomes. If the
final_qc_outcome flag of this class' instance is set to true, the
outcome is also marked as 'Final', otherwise it's marked as
'Preliminary' (examples: 'Accepted Final', 'Rejected Preliminary').
By default the final_qc_outcome flag is false and the produced
outcomes are preliminary.

=head2 Retrieval of autoqc results to be evaluated

We will not try to second-guess here what is and what is not
a product. Therefore, it is possible to invoke this check on
any entity apart from, possibly, a run. At run time an attempt
will be made to retrieve autoqc results due to be evaluated.
If this attempt fails, the execute method of the check will
exit with an error. A failure to retrieve the autoqc results
might be for one of three reasons: (1) either the entity is not
an end product (example: a pool) and no such results exist
or (2) it is a product, but the autoqc results have not been
computed yet, or (3) they have, but their file system location
(if that's where we are looking) is different from expected
(ie given by the qc_in attribute).

The results of other autoqc checks are loaded either from the file
system (use_db attribute should be set to false, which is default)
or from a database (use_db attribute should be set to true).
npg_qc::autoqc::qc_store class is used to load results. In
contrast to npg_qc::autoqc::qc_store, if the database retrieval
is enabled, no fall back to a search on a file system is done.

=head2 Record of the evaluation criteria

The result object for this check records evaluation criteria
in a form that would not require any additional information to
repeate the evaluation as it was done at the time the check was
run.

All boolean operators are listed explicitly. The top-level
expression is either a conjunction or disjunction performed on
a list of expressions, each of wich can be, in turn, either a
math expression or a further boolean expression on a list of
expressions.

Examples:

  Assuming a = 2 and b = 5,
  {'and' => ["a-1 < 0", "b+3 > 10"]} translates to
  (a-1 > 0) && (b+3 > 10) and evaluates to false, while
  {'or' => ["a-1 > 0", "b+3 > 10"]} translates to
  (a-1 > 0) || (b+3 > 10) and evaluates to true.

  Assuming additionally c = 3 and d = 1,
  {'and' => ["a-1 > 0", "b+3 > 5", {'or' => ["c-d > 0",  "c-d < -1"]}]}
  translates to
  (a-1 > 0) && (b+3 > 5) && ((c-d > 0) || (c-d < -1))
  and evaluates to true.

if both acceptance and rejection criteria have to be accomodated, this
can be done in the following way (note the negation operator):

  {
    'and' => [
      {'not' => {'or' => [$rejection_expr1, $rejection_expr2]}},
      {'and' => [$acceptance_expr1, $acceptance_expr2]}}
             ]
  }

The outcome of the evaluation will be either true or false. The undecided
outcome can be assigned if the overall expression evaluates to false and
a full evaluation was performed (ie the acceptance branch was evaluated).

=head1 SUBROUTINES/METHODS

=head2 use_db

A boolean read-only attribute, false by default.
If set to false, autoqc results are loaded from the qc_in path.
If set to true, they are loaded from the database.

=cut

has 'use_db' => (
  isa => 'Bool',
  is  => 'ro',
);

=head2 final_qc_outcome

A boolean read-only attribute, false by default.
If set to false, the result of the evaluation is saved as a
preliminary manual QC outcome. If set to true,  the result of the
evaluation is saved as a final manual QC outcome.

=cut

has 'final_qc_outcome' => (
  isa => 'Bool',
  is  => 'ro',
);

=head2 conf_path

An attribute, an absolute path of the directory with
the pipeline's configuration files. Inherited from
npg_tracking::util::pipeline_config

=head2 conf_file_path

A method. Return the path of the product configuration file.
 Inherited from npg_tracking::util::pipeline_config

=head2 can_run

Returns true if the check can be run, ie relevant to the study
and library type evaluation criteria are defined, false otherwise. 

=cut

sub can_run {
  my $self = shift;

  if (not keys %{$self->_criteria}) {
    $self->result->add_comment(
      'No criteria defined in the product configuration file');
    return 0;
  }
  return 1;
}

=head2 execute

Returns early if the can_run method returns false. Otherwise a full
evaluation of autoqc results for this product is performed. If auto
qc results necessary to perform the evaluation are not available,
an error is raised. 

=cut

sub execute {
  my $self = shift;

  $self->can_run() or return;
  $self->result->criteria($self->_criteria);
  $self->result->pass($self->evaluate);
  $self->result->qc_outcome($self->_generate_qc_outcome);

  return;
}

=head2 evaluate

Main evaluation algorithm. Current implementation is very simple:
all criteria found in the product configuration file are assumed
to be equally essential. Therefore, a conjunction (AND) operator
is applied to a list of this criteria.

Private methods and attributes of this class and the result class
implementation for this check are capable of supporting a more
complex algorithm should this become necessary in future. 

Returns 1 if all evaluated conditions were satisfied, otherise
returns 0. Sets the evaluation_results attribute of the results
object instance.

In future we might have both acceptance and rejection criteria
defined, adding an undefined value as a legitimate outcome.

=cut

sub evaluate {
  my $self = shift;

  my $emap = $self->_evaluate_expressions_array($self->_expressions);
  while (my ($e, $o) = each  %{$emap}) {
    $self->result->evaluation_results()->{$e} = $o;
  }

  return $self->_apply_operator([values %{$emap}], $CONJUNCTION_OP);
}

has '_lims' => (
  isa        => 'st::api::lims',
  is         => 'ro',
  lazy_build => 1,
);
sub _build__lims {
  my $self = shift;
  return st::api::lims->new(rpt_list => $self->rpt_list);
}

has '_criteria' => (
  isa        => 'HashRef',
  is         => 'ro',
  lazy_build => 1,
);
sub _build__criteria {
  my $self = shift;

  my $rewritten = {};
  my @criteria  = ();

  my $strict = 1;
  my $study_config = $self->study_config($self->_lims(), $strict);
  my $description = $self->composition->freeze;

  if (keys %{$study_config}) {

    if ($study_config->{$ROBO_KEY}) {
      my $lib_type = $self->_lims->library_type;
      $lib_type or croak "Library type is not defined for $description";
      $self->result->library_type($lib_type);
      # We are going to compare library type strings in lower case
      # because the case for this type of LIMs data might be inconsistent.
      my $original_lib_type = $lib_type;
      $lib_type = lc $lib_type;

      #####
      # We expect that the same criterium or a number of criteria can be
      # relevant for multiple library types. Therefore, under the robo_qc
      # section we expect a list of lists of criteria, each lower-level list
      # being assiciated with at least one and potentially more library types.
      # In practice under robo_qc we have a list of hashes, where each hash
      # contains the 'library_type' key pointing to an array of relevant library
      # types and the 'criteria' key pointing to an array or criteria. Criteria
      # for a particular library type can be split between different hashes.
      #
      foreach my $criteria_set (@{$study_config->{$ROBO_KEY}}) {
        $criteria_set->{$LIBRARY_TYPE_KEY} or croak "$LIBRARY_TYPE_KEY key is missing";
        $criteria_set->{$ACCEPTANCE_CRITERIA_KEY} or croak "$ACCEPTANCE_CRITERIA_KEY key is missing";
        if (any {$_ eq $lib_type} map { lc } @{$criteria_set->{$LIBRARY_TYPE_KEY}}) {
          #####
          # A very simple criteria format - a list of strings - is used for now.
          # Each string represents a math expression. It is assumed that the
          # conjunction operator should be used to form the boolean expression
          # that should give the result of the evaluation. Therefore, at the
          # moment it is safe to collect all criteria in a single list.
          # 
          push @criteria, @{$criteria_set->{$ACCEPTANCE_CRITERIA_KEY}};
        }
      }
      if (@criteria) {
        # Applying the conjunction operator to all list members.
        $rewritten = {$CONJUNCTION_OP => \@criteria};
      } else {
        carp "No roboqc criteria defined for library type '$original_lib_type'";
      }
    } else {
      carp "$ROBO_KEY section is not present for $description";
    }
  } else {
    carp "Study config not found for $description";
  }

  return $rewritten;
}

has '_expressions'  => (
  isa        => 'ArrayRef',
  is         => 'ro',
  lazy_build => 1,
);
sub _build__expressions {
  my $self = shift;
  my $expressions = [];
  _traverse($self->_criteria, $expressions);
  return $expressions;
}

has '_result_class_names'  => (
  isa        => 'ArrayRef',
  is         => 'ro',
  lazy_build => 1,
);
sub _build__result_class_names {
  my $self = shift;
  my @class_names = uniq sort
                    map { _class_name_from_expression($_) }
                    @{$self->_expressions()};
  return \@class_names;
}

has '_qc_store' => (
  isa        => 'npg_qc::autoqc::qc_store',
  is         => 'ro',
  lazy_build => 1,
);
sub _build__qc_store {
  my $self = shift;
  return npg_qc::autoqc::qc_store->new(
           use_db      => $self->use_db,
           checks_list => $self->_result_class_names
         );
}

#####
# Two different approaches for loading results. We can try to perform
# evaluationing expression after expression and load the necessary result
# objects as we go. Or we can pre-load all results that will be needed.
# We choose the latter and raise an error if any results are missing.
# The error will report what is found and what is expected, so that
# the user has the full picture at once.
#
has '_results'  => (
  isa        => 'HashRef',
  is         => 'ro',
  lazy_build => 1,
);
sub _build__results {
  my $self = shift;

  my $collection = $self->use_db ?
    $self->_qc_store->load_from_db_via_composition([$self->composition]) :
    $self->_qc_store->load_from_path($self->qc_in);

  my $d = $self->composition->digest;
  my @results = grep { $_->composition->digest eq $d } $collection->all;

  # We should have the right number of the right types of results.
  my %h = map { $_ => 0 } @{$self->_result_class_names};
  foreach my $r (@results) {
    my  $class_name = $r->class_name;
    exists $h{$class_name} or croak "Loaded unwanted class $class_name";
    ($h{$class_name} == 0) or croak "Multiple entries for class $class_name";
    $h{$class_name} = $r;
  }

  my $num_found = scalar grep { $_ } values %h;
  my $num_expected = scalar @{$self->_result_class_names};
  if ($num_expected != $num_found) {
    my $m = join q[, ], @{$self->_result_class_names};
    $m = "Expected results for $m, found ";
    $m .= $num_found
          ? 'results for ' . join q[, ], grep { $h{$_} } sort keys %h
          : 'none';
    croak $m;
  }

  return \%h;
}

sub _class_name_from_expression {
  my $e = shift;
  my ($class_name) = $e =~ /\A(?:\W+)?(\w+)[.]/xms;
  $class_name or croak "Failed to infer class name from $e";
  return $class_name;
}

sub _traverse {
  my ($node, $expressions) = @_;

  # Simplest traversal for now. Ideally, this function should take
  # a callback so that different actions can be performed.
  my $node_type = ref $node;
  if ($node_type) {
    ($node_type eq 'HASH') or croak "Unknown node type $node_type";
    my @values = values %{$node};
    (scalar @values == 1) or croak 'More than one key-value pair';
    (ref $values[0] eq 'ARRAY') or croak 'Array value type expected';
    foreach my $n (@{$values[0]}) {
      _traverse($n, $expressions); # recursion
    }
  } else {
    push @{$expressions}, $node; # no need to recurse further
  }

  return;
}

#####
# Given an array of expressions, evaluates them in the context of available
# autoqc results. Maps outcomes (as 1 or 0) to expressions and returns this
# hash.
#
sub _evaluate_expressions_array {
  my ($self, $expressions) = @_;

  my $map = {};
  foreach my $e (@{$expressions}) {
    $map->{$e} = $self->_evaluate_expression($e);
  }

  return $map;
}

#####
# Applies a logical operator to all array members.
# Defaults to aplying the conjunction operator.
# Returns 0 or 1.
#
sub _apply_operator {
  my ($self, $outcomes, $operator) = @_;

  $operator ||= $CONJUNCTION_OP;
  ($operator eq $CONJUNCTION_OP) or ($operator eq $DISJUNCTION_OP)
    or croak "Unknown logical operator $operator";

  my $outcome = $operator eq $CONJUNCTION_OP ?
                all { $_ } @{$outcomes}  : any { $_ } @{$outcomes};

  return $outcome ? 1 : 0;
}

#####
# Evaluates a single expression in the context of available autoqc results.
# Returns 0 or 1.
#
sub _evaluate_expression {
  my ($self, $e) = @_;

  my $class_name = _class_name_from_expression($e);
  my $obj = $self-> _results->{$class_name};
  # We should not get this far with an error in the configuration
  # filr, but just in case...
  $obj or croak "No autoqc result for evaluation of '$e'";

  ##no critic (ValuesAndExpressions::RequireInterpolationOfMetachars)
  my $replacement = q[$result->];
  ##use critic
  my $perl_e = $e;
  $perl_e =~ s/$class_name[.]/$replacement/xmsg;

  my $evaluator = sub {
    my $result = shift;
    ##no critic (BuiltinFunctions::ProhibitStringyEval)
    my $o = eval $perl_e; # Evaluate Perl string expression
    ##use critic
    if ($EVAL_ERROR) {
      my $err = $EVAL_ERROR;
      croak "Error evaluating expression '$perl_e' derived from '$e': $err";
    }
    return $o ? 1 : 0;
  };

  return $evaluator->($obj);
}

sub _generate_qc_outcome {
  my $self = shift;

  #####
  # Any of Accepted, Rejected, Undecided outcomes can be returned here
  my $outcome = npg_qc::Schema::Mqc::OutcomeDict->generate_short_description(
    $self->final_qc_outcome ? 1 : 0, $self->result->pass);

  return { mqc_outcome => $outcome,
           timestamp   => create_current_timestamp(),
           username    => $ROBO_KEY };
}

__PACKAGE__->meta->make_immutable();

1;

__END__

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Carp

=item Readonly

=item List::MoreUtils

=item English

=item WTSI::DNAP::Utilities::Timestamp

=item st::api::lims

=item npg_tracking::util::pipeline_config

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2019 GRL

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
