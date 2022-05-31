## General

- Use correct RT ticket number.
- Set id_run, position and tag_index accordingly.
- Wrap database changes into a transaction, which initially shoudl have a clause
  to fail it so that it can be tried out (see some examples below).

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

## Assigning the library outcome value

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

