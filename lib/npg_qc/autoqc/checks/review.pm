package npg_qc::autoqc::checks::review;

use Moose;
use namespace::autoclean;
use Carp;
use Readonly;
use List::MoreUtils qw/all any none uniq/;
use English qw/-no_match_vars/;
use DateTime;
use Try::Tiny;

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
Readonly::Scalar my $CRITERIA_KEY     => q[criteria];
Readonly::Scalar my $QC_TYPE_KEY      => q[qc_type];
Readonly::Scalar my $LIBRARY_TYPE_KEY => q[library_type];
Readonly::Scalar my $ACCEPTANCE_CRITERIA_KEY => q[acceptance_criteria];

Readonly::Scalar my $QC_TYPE_DEFAULT  => q[mqc];
Readonly::Array  my @VALID_QC_TYPES   => ($QC_TYPE_DEFAULT, q[uqc]);

Readonly::Scalar my $TIMESTAMP_FORMAT_WOFFSET => q[%Y-%m-%dT%T%z];

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::autoqc::checks::review

=head1 SYNOPSIS

  my $check = npg_qc::autoqc::checks::review->new(qc_in => 'dir_in');
  $check->execute();

=head1 DESCRIPTION

=head2 Overview

This checks evaluates the results of other autoqc checks
against a predefined set of criteria.

If data product acceptance criteria for a project are defined,it
is possible to introduce a degree of automation into the manual
QC process. To provide interoperability with the API supporting
the manual QC process, the outcome of the evaluation performed by
this check is recorded not only as a simple undefined, pass or
fail as in other autoqc checks, but also, optionally, as one of
valid manual or user QC outcomes.

=head2 Types of criteria

The robo section of the product configuration file sits within
the configuration for a particular study. However, evaluation
criteria for samples in the same study might vary depending on
the sequencing instrument type, library type, sample type, etc.
It might be reasonable to exclude some samples from a robo
process. The criteria key of the robo configuration contains an
array of criteria objects each of which could contain up to three
further keys, one for acceptance criteria, one for rejection
criteria and one for applicability criteria. The aceptance
and/or rejection criteria are evaluated if either the applicability
criteria have been satisfied or no applicability criteria are
defined.

The applicability criteria for each criteria object should be
set in such a way that the order of evaluation of the criteria
array does not matter. If applicability criteria in each of the
criteria objects fail for a product, no QC outcome is assigned
and the pass attribute of the review result object remains unset.
The product cannot satisfy a set of applicability criteria in
multiple criteria object, this is considered to be an error.

=head2 QC outcomes

A valid manual QC outcome is one of the values from the library
qc outcomes dictionary (mqc_library_outcome_dict table of the
npg_qc database), i.e. one of 'Accepted', 'Rejected' or 'Undecided'
outcomes. If the final_qc_outcome flag of this class' instance is
set to true, the outcome is also marked as 'Final', otherwise it is
marked as 'Preliminary' (examples: 'Accepted Final',
'Rejected Preliminary'). By default the final_qc_outcome flag is
false and the produced outcomes are preliminary.

A valid user QC outcome is one of the values from the
uqc_outcome_dict table of the npg_qc database. A concept of
the finality and, hence, immutability of the outcome is not
applicable to user QC outcome.

The type of QC outcome can be configured within the Robo QC
section of product configuration. The default type is library
manual QC.

=head2 Rules for assignment of the QC outcome

The rules below apply to a single criteria object.

If only acceptance criteria are present, the 'Accepted' outcome
is assigned if the outcome of evaluation is true and the 'Rejected'
outcome is assigned otherwise.

If only the rejection criteria are present, the 'Rejected' outcome
is assigned if the regection criteria evaluate to true, otherwise
the 'Undecided' outcome is assigned.

If both acceptance and rejection criteria are present, the 'Accepted'
outcome is assigned in case the acceptance criteria evaluate to true,
the 'Rejected' outcome is assigned if the regection criteria evaluate
to true, the 'Undecided' outcome is assigned in other cases.

A special case of regection criteria always evaluating to false is
available to force the outcome to be 'Undecided' when the acceptance
criteria evaluate to false. 

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

  Negation operator example:
  {
    'and' => [
      {'not' => {'or' => [$rejection_expr1, $rejection_expr2]}},
      {'and' => [$acceptance_expr1, $acceptance_expr2]}}
             ]
  }

Since both the conjunction and disjunction operators are idempotent in
Boolean algebra, the order of expressions within the arrays does not
affect the outcome of evaluation. However, the order does matter when
comparing criteria either as data structures or serialized data
structures. To ensure that the criteria can be compared, the expressions
in the arrays are ordered alphabetically. Therefore, the criteria record
in the result object might vary slightly from the configuration file
record.

The current product configuration supports arrays of criteria where
all criteria is the array are equally essential. Therefore, a conjunction
(AND) operator is applied to a list of these criteria.

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

Returns true if the check can be run, ie if at least one set of
criteria potentially applies to the product, false otherwise. This
method might be too optimistic in its evaluation since it might not
be possible to determine eligibility till all autoqc results for
the product are available.  

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
evaluation of autoqc results for this product is performed. If
autoqc results that are necessary to perform the evaluation are not
available or there is some other problem with evaluation, an error
is raised if the final_qc_outcome flag is set to true. If this flag
is false, the error is captured, logged as a comment and an undefined
qc outcome is assigned. 

=cut

sub execute {
  my $self = shift;

  $self->can_run() or return;
  $self->result->criteria($self->_criteria);
  my $md5 = $self->result->generate_checksum4data($self->result->criteria);
  $self->result->criteria_md5($md5);

  try {
    $self->result->pass($self->evaluate);
  } catch {
    my $err = 'Not able to run evaluation: ' . $_;
    $self->final_qc_outcome && croak $err;
    $self->result->add_comment($err);
  };
  $self->result->qc_outcome(
    $self->generate_qc_outcome($self->_outcome_type(), $md5));

  return;
}

=head2 evaluate

Method implementing the top level evaluation algorithm. Returns the outcome
of the evaluation either as an explicitly set boolean value (0 or 1) or as
an undefined value. An undefined retuen is semantically different from an
explicit 0 return.

=cut

sub evaluate {
  my $self = shift;

  my $emap = $self->_evaluate_expressions_array($self->_expressions);
  while (my ($e, $o) = each  %{$emap}) {
    $self->result->evaluation_results()->{$e} = $o;
  }

  return $self->_apply_operator([values %{$emap}], $CONJUNCTION_OP);
}

=head2 generate_qc_outcome

Returns a hash reference representing the QC outcome.

  my $u_outcome = $r->generate_qc_outcome('uqc', $md5);
  my $m_outcome = $r->generate_qc_outcome('mqc');

=cut

sub generate_qc_outcome {
  my ($self, $outcome_type, $md5) = @_;

  $outcome_type or croak 'outcome type should be defined';

  my $package_name = 'npg_qc::Schema::Mqc::OutcomeDict';
  my $pass = $self->result->pass;
  #####
  # Any of Accepted, Rejected, Undecided outcomes can be returned here
  my $outcome = ($outcome_type eq $QC_TYPE_DEFAULT)
    ? $package_name->generate_short_description(
      $self->final_qc_outcome ? 1 : 0, $pass)
    : $package_name->generate_short_description_prefix($pass);

  $outcome_type .= '_outcome';
  my $outcome_info = { $outcome_type => $outcome,
                       timestamp   => create_current_timestamp(),
                       username    => $ROBO_KEY};
  if ($outcome_type =~ /\Auqc/xms) {
    my @r = ($ROBO_KEY, $VERSION);
    $md5 and push @r, $md5;
    $outcome_info->{'rationale'} = join q[ ], @r;
  }

  return $outcome_info;
}

=head2 lims

st::api::lims object corresponding ti this object's rpt_list
attribute; this accessor can only be used to set the otherwise
private attribute. 

=cut

has 'lims' => (
  isa        => 'st::api::lims',
  is         => 'ro',
  lazy_build => 1,
);
sub _build_lims {
  my $self = shift;
  return st::api::lims->new(rpt_list => $self->rpt_list);
}

has '_robo_config' => (
  isa        => 'HashRef',
  is         => 'ro',
  lazy_build => 1,
);
sub _build__robo_config{
  my $self = shift;

  my $message;
  my $strict = 1; # Parse study section only, ignore the default section.
  my $config = $self->study_config($self->lims(), $strict);

  if (keys %{$config}) {
    $config = $config->{$ROBO_KEY};
    $config or $message = "$ROBO_KEY section is not present";
    if (not $message and
        ((ref $config ne 'HASH') or not $config->{$CRITERIA_KEY})) {
      $message = "$CRITERIA_KEY section is not present";
    }
  } else {
    $message = 'Study config not found';
  }

  if ($message) {
    carp $message . ' for ' .  $self->composition->freeze;
    return {};
  }

  return $config;
}

has '_criteria' => (
  isa        => 'HashRef',
  is         => 'ro',
  lazy_build => 1,
);
sub _build__criteria {
  my $self = shift;

  my $rewritten = {};

  (keys %{$self->_robo_config}) or return $rewritten;

  my $lib_type = $self->lims->library_type;
  $lib_type or croak 'Library type is not defined for ' .  $self->composition->freeze;
  # We are going to compare library type strings in lower case
  # because the case for this type of LIMs data might be inconsistent.
  my $original_lib_type = $lib_type;
  $lib_type = lc $lib_type;
  # We will save the original library type.
  $self->result->library_type($original_lib_type);

  my @criteria  = ();

  #####
  # We expect that the same criterium or a number of criteria can be
  # relevant for multiple library types. Therefore, under the robo_qc
  # criteria section we expect a list of lists of criteria, each lower-level list
  # being assiciated with at least one and potentially more library types.
  # In practice under this section we have a list of hashes, where each hash
  # contains the 'library_type' key pointing to an array of relevant library
  # types and the 'criteria' key pointing to an array or criteria. Criteria
  # for a particular library type can be split between different hashes.
  #
  foreach my $criteria_set (@{$self->_robo_config->{$CRITERIA_KEY}}) {
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

  # Sort to ensure a consistent order of expressions in the array.
  # Merge identical entries.
  @criteria = uniq (sort @criteria);
  # Applying the conjunction operator to all list members.
  if (@criteria) {
    $rewritten = {$CONJUNCTION_OP => \@criteria};
  } else {
    carp "No roboqc criteria defined for library type '$original_lib_type'";
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
  # Copy class names so that the qc_store object cannot change
  # our data.
  my @l = @{$self->_result_class_names};
  return npg_qc::autoqc::qc_store->new(
           use_db      => $self->use_db,
           checks_list => \@l
         );
}

#####
# Two possible approaches for loading results. We can try to perform
# the evaluation step by step and load the necessary result objects
# as we go. Or we can pre-load all results that will be needed.
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

#####
# Simplest traversal for now. Ideally, this function should take
# a callback so that different actions can be performed.
#
sub _traverse {
  my ($node, $expressions) = @_;

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
  # file, but just in case...
  $obj or croak "No autoqc result for evaluation of '$e'";

  ##no critic (ValuesAndExpressions::RequireInterpolationOfMetachars)
  my $replacement = q[$result->];
  ##use critic
  my $perl_e = $e;
  $perl_e =~ s/$class_name[.]/$replacement/xmsg;

  my $evaluator = sub {
    my $result = shift;
    # Force an error when operations on undefined values are
    # are attempted.
    use warnings FATAL => 'uninitialized';
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

sub _outcome_type {
  my $self = shift;

  my $outcome_type = $self->_robo_config()->{$QC_TYPE_KEY};
  if ($outcome_type) {
    if (none { $outcome_type eq $_ } @VALID_QC_TYPES) {
      croak "Invalid QC type '$outcome_type' in product configuration";
    }
  } else {
    $outcome_type = $QC_TYPE_DEFAULT;
  }

  return $outcome_type;
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

Copyright (C) 2019,2020 Genome Research Ltd.

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
