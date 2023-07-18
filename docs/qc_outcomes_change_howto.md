# Guidance for Changing QC Outcomes

- Use the correct RT ticket number.
- Set id_run, position and tag_index accordingly.
- Wrap database changes into a transaction, which initially should have
  a clause to fail it so that it can be tried out (see some examples below).

## Toggle the outcome of a single library

QC outcome will change from `pass` to `fail` or `fail` to `pass`. 

```
use npg_qc::Schema;
my $rs=npg_qc::Schema->connect()->resultset("MqcLibraryOutcomeEnt")
  ->search_autoqc({id_run=>X,position=>Y,tag_index=>X});
if ($rs->count == 1) {
  my $row=$rs->next;
  print "Current outcome: ".$row->mqc_outcome->short_desc;
  $row->toggle_final_outcome($ENV{"USER"}, "RT#XXXXXX");
  print "New outcome: ".$row->mqc_outcome->short_desc;
} else {
  die "no result or multiple results"
}
```

## Toggle sequencing outcome for a lane

QC outcome will change from `pass` to `fail` or `fail` to `pass`.

```
use npg_qc::Schema;
my $rs=npg_qc::Schema->connect()->resultset("MqcOutcomeEnt")
  ->search({id_run=>X,position=>Y});
if ($rs->count == 1) {
  my $row=$rs->next;
  print "Current outcome: ".$row->mqc_outcome->short_desc;
  $row->toggle_final_outcome($ENV{"USER"}, "RT#XXXXXX");
  print "New outcome: ".$row->mqc_outcome->short_desc;
} else {
  die "no result or multiple results"
}
```

## Assign the library outcome value

When the lane outcome is changed from `fail` to `pass`, having consulted
the requestor, you might want to assign a pass to libraries.

```
use npg_qc::Schema;
my $s = npg_qc::Schema->connect();
# Use transaction.
$s->txn_do( sub {
  my $rs=npg_qc::Schema->connect()->resultset("MqcLibraryOutcomeEnt")
    ->search({id_run=>X,position=>Y});
  while (my $row=$rs->next) {
    print $row->tag_index . " Current outcome: ".$row->mqc_outcome->short_desc;
    $row->update_outcome({"mqc_outcome" => "Accepted final"},
      $ENV{"USER"}, "RT#XXXX");
    print "New outcome: ".$row->mqc_outcome->short_desc;
  }
  # Comment out the next statement when ready to update the values.
  die 'End of transaction, deliberate error';
});
```

## Create sequencing `fail` for lanes

This example covers the case when QC outcomes have to be created for entities,
which do not have any associated QC outcomes.

A typical scenario is when the `mqc_skipper` pushed the data through for
assignment downstream, the data is rejected there, and the subsequent local
QC assessment assigns a `fail`.

```
use npg_qc::mqc::outcomes::keys qw/ $SEQ_OUTCOMES /;
use npg_qc::Schema;
use npg_qc::mqc::outcomes;
use Data::Dumper;

my $outcomes = {};
my $info = {};
my $id_run = X;
foreach my $l (1..4) {
  my $key= join q(:),$id_run,$l;
  $outcomes->{$SEQ_OUTCOMES}->{$key} = {mqc_outcome=>q(Rejected final)};
  $info->{$key}=[];
}

print Dumper [$outcomes];
my $o = npg_qc::mqc::outcomes->new(qc_schema => npg_qc::Schema->connect());
$o->save($outcomes, $ENV{USER}, $info);
```

## Create `pass` for a lane and all its samples

This is an unusual scenario, but we do get requests like this
when the QC team has problems with SeqQC UI.

A full script for one lane is given below.

```
#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;

use npg_qc::mqc::outcomes::keys qw/ $SEQ_OUTCOMES $LIB_OUTCOMES/;
use npg_qc::Schema;
use npg_qc::mqc::outcomes;
use WTSI::DNAP::Warehouse::Schema;

# Inputs from the RT ticket.
# Unfortunately, the high-level API we are going to use does not
# allow us to pass through the RT ticket number.
my $id_run = XXXX; # CHANGE!
my $position = Y;  # CHANGE!
my $user = 'USER_NAME'; # CHANGE!
my $outcome = q(Accepted final); # Must match the database dictionary value.
# End of inputs from the RT ticket.

print sprintf '%sChanging outcomes for run %i lane %i to "%s" as user %s%s',
  qq[\n], $id_run, $position, $outcome, $user, qq[\n];

my $mlwh_schema = WTSI::DNAP::Warehouse::Schema->connect();
# Need to exclude PhiX tag index.
# Tag zero record is not linked to the iseq_flowcell table.
# Note that the number sequence between min and max tag index
# might have gaps.
my $rs = $mlwh_schema->resultset('IseqProductMetric')->search(
  {'me.id_run' => $id_run,
   'me.position' => $position,
   'iseq_flowcell.entity_type' => 'library_indexed'},
  {join => 'iseq_flowcell',
   order_by => 'me.tag_index',
   columns => 'tag_index' }
);
my @tag_indexes = map {$_->tag_index} $rs->all();

print "\nNUMBER OF TAGS: " . @tag_indexes . qq[\n];
print "MIN TAG " . $tag_indexes[0] . qq[\n];
print "MAX TAG " . $tag_indexes[-1] . qq[\n\n];

my $schema = npg_qc::Schema->connect();
my $outcomes = {};
my $info = {};

my $lane_key= join q(:),$id_run,$position;
$outcomes->{$SEQ_OUTCOMES}->{$lane_key} = {mqc_outcome => $outcome};
$info->{$lane_key}=\@tag_indexes;

foreach my $tag_index (@tag_indexes) {
  my $key= join q(:),$id_run,$position,$tag_index;
  $outcomes->{$LIB_OUTCOMES}->{$key} = {mqc_outcome => $outcome};
}

my $o = npg_qc::mqc::outcomes->new(qc_schema => $schema);
my $saved;
$schema->txn_do( sub {
  $saved = $o->save($outcomes, $user, $info);
  # Comment out the next statement when ready to update the values.
  die 'End of transaction, deliberate error';
});

if ($saved) {
  print Dumper $saved;
} else {
  print 'Nothing to print?';
}
```
