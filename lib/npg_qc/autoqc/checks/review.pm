package npg_qc::autoqc::checks::review;

use Moose;
use namespace::autoclean;
use Carp;
use Readonly;
use List::MoreUtils qw/all any none uniq/;
use English qw/-no_match_vars/;
use DateTime;
use Try::Tiny;
use Class::Load qw/load_class/;

use WTSI::DNAP::Utilities::Timestamp qw/create_current_timestamp/;
use st::api::lims;
use npg_tracking::illumina::runfolder;
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
Readonly::Scalar my $APPLICABILITY_CRITERIA_KEY => q[applicability_criteria];
Readonly::Scalar my $LIMS_APPLICABILITY_CRITERIA_KEY => q[lims];
Readonly::Scalar my $SEQ_APPLICABILITY_CRITERIA_KEY => q[sequencing_run];
Readonly::Array  my @APPLICABILITY_CRITERIA_TYPES => (
  $LIMS_APPLICABILITY_CRITERIA_KEY, $SEQ_APPLICABILITY_CRITERIA_KEY
                                                     );
Readonly::Scalar my $ACCEPTANCE_CRITERIA_KEY    => q[acceptance_criteria];

Readonly::Scalar my $QC_TYPE_LIB => q[mqc];
Readonly::Scalar my $QC_TYPE_SEQ => q[mqc_seq];

Readonly::Scalar my $TIMESTAMP_FORMAT_WOFFSET => q[%Y-%m-%dT%T%z];

Readonly::Scalar my $CLASS_NAME_SPEC_DELIM => q[:];
Readonly::Scalar my $CLASS_NAME_SPEC_RE    =>
  qr/\A(?:\W+)? (\w+) (?: $CLASS_NAME_SPEC_DELIM (\w+))?[.]/xms;

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::autoqc::checks::review

=head1 SYNOPSIS

  my $check = npg_qc::autoqc::checks::review->new(qc_in => 'dir_in');
  $check->execute();

=head1 DESCRIPTION

=head2 Overview

This checks evaluates the results of other autoqc checks against a predefined
set of criteria.

If data product acceptance criteria are defined, it is possible to introduce
a degree of automation into the QC process. To provide interoperability with
the API supporting the manual QC process, the outcome of the evaluation is
recorded not only as a simple C<undefined>, C<pass> or C<fail> as in other
autoqc checks, but also as one of valid manual lane or library-level QC
outcomes.

=head2 Types of criteria

The C<robo> section of the product configuration file sits either within
the configuration for a particular study or in the C<default> section, or
in both locations. For a given entity a study-specific RoboQC definition
takes precedence over the default one.

Evaluation criteria for samples vary depending on the sequencing instrument
and flowcell type, library type, sample reference, etc. Each of the
C<criteria> keys of the C<robo> configuration contains two further keys, one
for acceptance and one for applicability criteria.

The applicability criteria for each criteria object should be set in such
a way that the order of evaluation of the criteria array does not matter.
If applicability criteria in all of the criteria objects are not satisfied,
the evaluation is not performed, no QC outcome is assigned and the C<pass>
attribute of the review result object remains unset.

The product can satisfy applicability criteria in at most one criteria object.
If none of the study-specific applicability criteria are satisfied, the review
check does not proceed even if the product satisfies one of the applicability
criteria in the C<default> section.

=head2 QC outcomes values

A valid manual QC outcome is one of the values from the library
qc outcomes dictionary (C<mqc_library_outcome_dict> table of the
QC database), i.e. one of 'Accepted', 'Rejected' or 'Undecided'
outcomes. If the C<final_qc_outcome> flag of the review check object
is set to a C<true> value, the outcome is also marked as 'Final',
 otherwise it is marked as 'Preliminary' (examples: C<Accepted Final>,
C<Rejected Preliminary>). By default the C<final_qc_outcome> flag is
C<false> and the produced outcomes are preliminary.

=head2 QC outcomes types

The behaviour mimics manual QC process via SeqQC UI. For lane entities
'sequencing' QC outcomes are generated. For samples 'library' QC outcomes
are generated.

=head2 Rules for assignment of the QC outcome

The rules below apply to a single criteria object.

The 'Accepted' outcome is assigned if the outcome of evaluation is
a C<true> value, the 'Rejected' outcome is assigned otherwise.

=head2 Retrieval of autoqc results to be evaluated

It is possible to invoke this check on any entity. At run time an
attempt is made to retrieve autoqc results for this entity (product),
which are relevant to RoboQC for this product. If this attempt
fails, the C<execute> method of the check will exit with an error. A
failure to retrieve the autoqc results might be for one of three
reasons: (1) the autoqc results have not been computed yet, or (2) the
file system location is different from the one given by C<qc_in>
attribute.

The autoqc results are retrieved either from the file system (C<use_db>
attribute should be set to C<false>, which is default) or, C<use_db> is
set to a C<true> value, from a database. C<npg_qc::autoqc::qc_store>
class is used to retrieve results. In contrast to the default behaviour
of C<npg_qc::autoqc::qc_store> class, if no result are retrieved from
the database, a search on a file system is not attempted.

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
      {'not' => {'or' => [$expr1, $expr2]}},
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
all criteria in the array are equally essential. Therefore, a conjunction
(AND) operator is applied to a list of these criteria.

=head1 SUBROUTINES/METHODS

=head2 use_db

A boolean read-only attribute, C<false> by default.
If set to C<false>, autoqc results are loaded from the C<qc_in> path.
If set to C<true>, the results are loaded from the database.

=cut

has 'use_db' => (
  isa => 'Bool',
  is  => 'ro',
);

# The DBIx schema object for the database with autoqc results. 
has '_qc_schema' => (
  isa        => 'Maybe[npg_qc::Schema]',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
);
sub _build__qc_schema {
  my $self = shift;
  if ($self->use_db) {
    # Load into memory on demand since in production scenario
    # the database is used very rarely.
    load_class 'npg_qc::Schema';
    return npg_qc::Schema->connect();
  }
  return;
}

=head2 final_qc_outcome

A boolean read-only attribute, C<false> by default.

If set to C<false>, the result of the evaluation is saved as a
preliminary manual QC outcome. If set to C<true>,  the result of the
evaluation is saved as a final manual QC outcome.

=cut

has 'final_qc_outcome' => (
  isa => 'Bool',
  is  => 'ro',
);

=head2 conf_path

An attribute, an absolute path of the directory with the pipeline's
configuration files.

Inherited from C<npg_tracking::util::pipeline_config>.

=head2 conf_file_path

Method returning the path of the product configuration file.

Inherited from C<npg_tracking::util::pipeline_config>.

=head2 runfolder_path

The runfolder path, an optional attribute.

In case of complex products (multi-component compositions) it is only relevant
if all components belong to the same sequencing run. This attribute is used to
retrieve information from C<RunInfo.xml> and C<{r,R}unParameters.xml> files.

Some C<robo> configurations do not require information of this nature, thus the
attribute is optional. In practice the attribute has to be set to allow for
correct evaluation of applicability of all criteria of a production RoboQC
configuration.

If the information from the above-mentioned files is required, but the access
to the staging run folder is not available, the check cannot be run.

=cut

has 'runfolder_path' => (
  isa => 'Str',
  is  => 'ro',
  required => 0,
  predicate => 'has_runfolder_path',
);

=head2 BUILD

A method that is run before returning the new object instance to the caller.
Errors if any attributes of the object are in conflict.

=cut

sub BUILD {
  my $self = shift;
  if ($self->has_runfolder_path && !$self->get_id_run) {
    my $m = sprintf
      'Product defined by rpt list %s does not belong to a single run.',
      $self->rpt_list;
    croak "$m 'runfolder_path' attribute should not be set.";
  }
}

=head2 can_run

Returns a C<true> value if the check can be run, ie a valid RoboQC
configuration exists and one of the applicability criteria is satisfied for
this product.

=cut

sub can_run {
  my $self = shift;

  my $can_run = 1;
  my $message;

  if (!keys %{$self->_robo_config}) {
    $message = 'RoboQC configuration is absent';
    $can_run = 0;
  } else {
    my $num_criteria;
    try {
      $num_criteria = @{$self->_applicable_criteria};
    } catch {
      $message = "Error validating RoboQC criteria: $_";
      $can_run = 0;
    };
    if ($can_run && !$num_criteria) {
      $message = 'None of the RoboQC applicability criteria is satisfied';
      $can_run = 0;
    }
  }

  if (!$can_run && $message) {
    $self->result->add_comment($message);
    carp sprintf 'Review check cannot be run for %s . Reason: %s',
      $self->_entity_desc, $message;
  }

  return $can_run;
}

=head2 execute

Returns early without an error if C<can_run> method returns a C<false> value.

If C<can_run> returns a C<true> value, a full evaluation of autoqc results
for this product is performed. If autoqc results that are necessary to perform
the evaluation are not available or there is some other problem with evaluation,
an error is raised if the C<final_qc_outcome> flag is set to C<true>, otherwise
the error it is captured and and logged as a comment.

No QC outcome is assigned if the evaluation has not had a chance to run to a
successful completion.

=cut

sub execute {
  my $self = shift;

  $self->can_run() or return;

  if ( not keys %{$self->_criteria} ) {
    $self->result->add_comment('RoboQC is not applicable');
    return;
  }

  $self->result->criteria($self->_criteria);
  $self->result->criteria_md5(
    $self->result->generate_checksum4data($self->result->criteria)
  );
  my $err;

  try {
    $self->result->pass($self->evaluate);
  } catch {
    $err = 'Not able to run evaluation: ' . $_;
    $self->final_qc_outcome && croak $err;
    $self->result->add_comment($err);
  };
  not $err and $self->result->qc_outcome($self->generate_qc_outcome());

  return;
}

=head2 evaluate

Method implementing the top level evaluation algorithm. Returns the outcome
of the evaluation as C<0> for a fail or C<1> for a pass. Saves the outcomes of
evaluation of individual expressions in the C<evaluation_results> attribute of
the result object.

=cut

sub evaluate {
  my $self = shift;

  my $emap = $self->_evaluate_expressions_array($self->_expressions);
  $self->result->evaluation_results($emap);

  return $self->_apply_operator([values %{$emap}], $CONJUNCTION_OP);
}

=head2 generate_qc_outcome

Returns a hash reference representing the QC outcome.

  my $qc_outcome = $r->generate_qc_outcome();

The returned hash has three keys:

=over

=item C<timestamp> records the current time and is interpreted downstream
  as the time the QC decision was made.

=item C<username> with the value of C<'robo_qc'>, is interpreted downstream as
  the user who performed 'manual' QC.

=item C<mqc_outcome> or C<mqc_seq_outcome> for the outcome of the evaluation.
  Examples of values: C<Accepted preliminary>, C<Rejected final>. If lane-level
  evaluation is performed, the key is C<mqc_seq_outcome>, otherwise it is
  C<mqc_outcome>.

=back

=cut

sub generate_qc_outcome {
  my ($self) = @_;

  my $package_name = 'npg_qc::Schema::Mqc::OutcomeDict';
  my $pass = $self->result->pass;
  #####
  # Any of Accepted, Rejected, Undecided outcomes can be returned here
  my $outcome = $package_name->generate_short_description(
    $self->final_qc_outcome ? 1 : 0, $pass);

  my $outcome_type = ($self->lims->is_lane ? $QC_TYPE_SEQ : $QC_TYPE_LIB)
    . '_outcome';
  return { $outcome_type => $outcome,
           timestamp     => create_current_timestamp(),
           username      => $ROBO_KEY };
}

=head2 lims

C<st::api::lims> object corresponding to this object's C<rpt_list>
attribute. 

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

=head2 runfolder

C<npg_tracking::illumina::runfolder> object for C<runfolder_path> attribute
value.

=cut

has 'runfolder' => (
  isa        => 'npg_tracking::illumina::runfolder',
  is         => 'ro',
  lazy_build => 1,
);
sub _build_runfolder {
  my $self = shift;
  if ($self->has_runfolder_path) {
    return npg_tracking::illumina::runfolder->new(
      npg_tracking_schema => undef,
      runfolder_path => $self->runfolder_path,
      id_run => $self->get_id_run()
    );
  }
  croak 'runfolder_path argument is not set';
}

has '_entity_desc' => (
  isa        => 'Str',
  is         => 'ro',
  lazy_build => 1,
);
sub _build__entity_desc {
  my $self = shift;
  return $self->composition->freeze();
}

has '_robo_config' => (
  isa        => 'HashRef',
  is         => 'ro',
  lazy_build => 1,
);
sub _build__robo_config {
  my $self = shift;

  my $strict = 1; # Parse study section only, ignore the default section.
  my $config = $self->study_config($self->lims(), $strict);
  if ($config) {
    $config = $config->{$ROBO_KEY};
  }

  if (!$config) {
    carp 'Study-specific RoboQC config not found for ' . $self->_entity_desc;
    $config = $self->default_study_config()->{$ROBO_KEY};
  }

  if ($config) {
    (ref $config eq 'HASH') or croak
      'Robo config should be a hash in a config for ' . $self->_entity_desc;
    if (keys %{$config}) {
      $self->_validate_criteria($config);
    } else {
      carp 'RoboQC section of the product config file is empty';
    }
  }

  $config ||= {};

  return $config;
}

sub _validate_criteria {
  my ($self, $config) = @_;

  my $criteria_array = $config->{$CRITERIA_KEY};
  defined $criteria_array or croak
    "$CRITERIA_KEY section is not present in a robo config for " .
    $self->_entity_desc;
  (ref $criteria_array eq q[ARRAY]) or croak
    'Criteria is not a list in a robo config for ' . $self->_entity_desc;

  @{$criteria_array} or croak 'Criteria list is empty';

  foreach my $c ( @{$criteria_array} ) {
    (exists $c->{$APPLICABILITY_CRITERIA_KEY} &&
    exists $c->{$ACCEPTANCE_CRITERIA_KEY}) || croak sprintf
    'Each criteria should have both the %s and %s key present',
    $APPLICABILITY_CRITERIA_KEY, $ACCEPTANCE_CRITERIA_KEY;
  }

  return;
}

has '_applicable_criteria' => (
  isa        => 'ArrayRef',
  is         => 'ro',
  lazy_build => 1,
);
sub _build__applicable_criteria {
  my $self = shift;

  my @applicable = ();
  foreach my $criteria_definition ( @{$self->_robo_config->{$CRITERIA_KEY}} ) {

    my $applicability_definition = $criteria_definition->{$APPLICABILITY_CRITERIA_KEY};
    $applicability_definition or croak
      "$APPLICABILITY_CRITERIA_KEY is not defined for one of RoboQC criteria";

    my $c_applicable = 1;
    my $one_found = 0;
    for my $c_type (@APPLICABILITY_CRITERIA_TYPES) {
      exists $applicability_definition->{$c_type} or next;
      $one_found = 1;
      my $ac = $applicability_definition->{$c_type};
      (defined $ac and keys %{$ac}) or croak
        "$c_type type applicability criteria is not defined";
      $c_applicable = $self->_is_applicable($c_type, $ac);
      !$c_applicable && last; # Stop on the first non applicable.
    }
    $one_found or croak 'None of known applicability type criteria is defined. ' .
      'Known types: ' . join q[, ], @APPLICABILITY_CRITERIA_TYPES;
    $c_applicable && push @applicable, $criteria_definition; # Save if fully applicable.
  }

  return \@applicable;
}

sub _is_applicable {
  my ($self, $criteria_type, $acriteria) = @_;

  $criteria_type or croak
    'Applicability criteria type is not defined';
  $acriteria or croak
    "$criteria_type applicability criteria is not defined";
  (ref $acriteria eq 'HASH') or croak sprintf
    '%s section should be a hash in a robo config for %',
    $criteria_type, $self->_entity_desc;

  my $test = {};
  foreach my $prop ( keys %{$acriteria} ) {
    my $ref_test = ref $acriteria->{$prop};
    not $ref_test or ($ref_test eq 'ARRAY') or croak
      qq(Values for '$criteria_type' property '$prop' are neither a scalar nor ) .
      'an array in a robo config for ' . $self->_entity_desc;
    my @expected_values = $ref_test ? @{$acriteria->{$prop}} : ($acriteria->{$prop});
    my $value = $criteria_type eq $LIMS_APPLICABILITY_CRITERIA_KEY ?
      $self->lims->$prop : $self->runfolder->$prop;
    if (!defined $value) { # for example, boolean false values
      $value = q[];
    }
    $value = lc q[] . $value; # comparing as strings in lower case
    $test->{$prop} = any { $value eq lc q[] . $_ } @expected_values;
  }

  # assuming 'AND' for properties
  return all { $_ } values %{$test};
}

has '_criteria' => (
  isa        => 'HashRef',
  is         => 'ro',
  lazy_build => 1,
);
sub _build__criteria {
  my $self = shift;

  # Library type might be undefined. Example - lane level object.
  my $lib_type = $self->lims->library_type;
  if ($lib_type) {
    $self->result->library_type($lib_type);
  }

  my $num_criteria = scalar @{$self->_applicable_criteria};
  if ($num_criteria == 0) {
    return {};
  } elsif ($num_criteria > 1) {
    croak 'Multiple criteria sets are satisfied in a robo config';
  }
  #####
  # A very simple criteria format - a list of strings - is used for now.
  # Each string represents a math expression. It is assumed that the
  # conjunction operator should be used to form the boolean expression
  # that should give the result of the evaluation.
  #
  my @c = uniq sort @{$self->_applicable_criteria->[0]->{$ACCEPTANCE_CRITERIA_KEY}};

  return @c ? {$CONJUNCTION_OP => \@c} : {};
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
                    map { (_class_name_from_expression($_))[0] }
                    map { @{$_} } # dereference the array
                    values %{$self->_criteria()};

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
    qc_schema   => $self->_qc_schema,
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
  my %h = map { $_ => [] } @{$self->_result_class_names};
  foreach my $r (@results) {
    my  $class_name = $r->class_name;
    exists $h{$class_name} or croak "Loaded unwanted class $class_name";
    push @{$h{$class_name}}, $r;
  }

  my $num_found = scalar grep { @{$_} } values %h;
  my $num_expected = scalar @{$self->_result_class_names};
  if ($num_expected != $num_found) {
    my $m = join q[, ], @{$self->_result_class_names};
    $m = "Expected results for $m, found ";
    $m .= $num_found
          ? 'results for ' . join q[, ], grep { @{$h{$_}} } sort keys %h
          : 'none';
    croak $m;
  }

  return \%h;
}

sub _class_name_from_expression {
  my $e = shift;
  my ($class_name, $spec) = $e =~ $CLASS_NAME_SPEC_RE;
  $class_name or croak "Failed to infer class name from $e";
  return ($class_name, $spec);
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
# If runs successfully, returns 0 or 1, otherwise throws an error.
#
sub _evaluate_expression {
  my ($self, $e) = @_;

  my ($class_name, $spec) = _class_name_from_expression($e);
  my $obj_a = $self->_results->{$class_name};
  # We should not get this far with an error in the configuration
  # file, but just in case...
  $obj_a and @{$obj_a} or croak "No autoqc result for evaluation of '$e'";

  if ($spec) {
    my $pp_name2spec = sub {    # To get a match with what would have been
      my $pp_name = shift;      # used in the robo config, replace all
      $pp_name =~ s/\W/_/gsmx;  # 'non-word' characters.
      return $pp_name;
    };
    # Now have to choose one result. If the object is not an instance of
    # the generic autoqc result class, there will be an error at this point.
    # Making the code less specific is not worth the effort at this point.
    my @on_spec = grep { $pp_name2spec->($_->pp_name) eq $spec } @{$obj_a};
    @on_spec or croak "No autoqc $class_name result for $spec";
    $obj_a = \@on_spec;
  }

  (@{$obj_a} == 1) or croak "Multiple autoqc results for evaluation of '$e'";
  my $obj = $obj_a->[0];

  $obj or croak "No autoqc result for evaluation of '$e'";

  # Prepare the expression from the robo config for evaluation.
  my $placeholder = $class_name;
  $spec and ($placeholder .= $CLASS_NAME_SPEC_DELIM . $spec);
  my $replacement = q[$] . q[result->];
  my $perl_e = $e;
  $perl_e =~ s/$placeholder[.]/$replacement/xmsg;

  my $evaluator = sub { # Evaluation function
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

  # Evaluate and return the outcome.
  return $evaluator->($obj);
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

=item Try::Tiny

=item Date::Time

=item Class::Load

=item WTSI::DNAP::Utilities::Timestamp

=item st::api::lims

=item npg_tracking::illumina::runfolder

=item npg_tracking::util::pipeline_config

=item npg_qc::Schema

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2019,2020,2024 Genome Research Ltd.

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
