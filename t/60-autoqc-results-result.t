use strict;
use warnings;
use Test::More tests => 49;
use Test::Exception;

use_ok ('npg_qc::autoqc::results::result');
use_ok('npg_tracking::glossary::composition::factory');
use_ok('npg_tracking::glossary::composition::component::illumina');

{
    my $r = npg_qc::autoqc::results::result->new(id_run => 2, path => q[mypath], position => 1);
    isa_ok ($r, 'npg_qc::autoqc::results::result');
}

{
    my $r = npg_qc::autoqc::results::result->new(id_run => 2, path => q[mypath], position => 1);
    is($r->check_name(), q[result], 'check name');
    is($r->class_name(), q[result], 'class name');
    is($r->package_name(), q[npg_qc::autoqc::results::result], 'class name');
    is($r->tag_index, undef, 'tag index undefined');
    ok($r->has_composition, 'composition is built');
    my $c = $r->composition->get_component(0);
    is($c->id_run, 2, 'component run id');
    is($c->position, 1, 'component position');
    is($c->tag_index, undef, 'component tag index undefined');
    is($c->subset, undef, 'component subset is undefined');

    throws_ok {npg_qc::autoqc::results::result->new(path => q[mypath])}
      qr/Can only build old style results/,
      'object with an empty composition is not built';
    throws_ok {npg_qc::autoqc::results::result->new(position => 1, path => q[mypath])}
      qr/Can only build old style results/,
      'object with an empty composition is not built';
    throws_ok {npg_qc::autoqc::results::result->new(id_run => 3, path => q[mypath])}
      qr/Attribute \(position\) does not pass the type constraint/,
      'position is needed';
}

{
    my $f = npg_tracking::glossary::composition::factory->new();
    my $c = {id_run => 3, position => 4, tag_index => 5};
    my $comp1 = npg_tracking::glossary::composition::component::illumina->new($c);
    $f->add_component($comp1);
    $c->{'position'} = 5;
    my $comp2 = npg_tracking::glossary::composition::component::illumina->new($c);
    $f->add_component($comp2);
   
    my $r = npg_qc::autoqc::results::result->new(composition => $f->create_composition());
    is ($r->composition_subset(), undef, 'composition subset is undefined');

    $f = npg_tracking::glossary::composition::factory->new();
    $f->add_component($comp1);
    $f->add_component($comp2);
    $c->{'subset'} = 'human';
    my $comp3 = npg_tracking::glossary::composition::component::illumina->new($c);
    $f->add_component($comp3);

    $r = npg_qc::autoqc::results::result->new(composition => $f->create_composition());
    throws_ok {$r->composition_subset()} qr/Multiple subsets within the composition/,
      'error for multiple subsets';

    $f = npg_tracking::glossary::composition::factory->new();
    $f->add_component($comp3);
    $c->{'id_run'} = 6;
    my $comp4 = npg_tracking::glossary::composition::component::illumina->new($c);
    $f->add_component($comp4);
    
    $r = npg_qc::autoqc::results::result->new(composition => $f->create_composition());
    is ($r->composition_subset(), 'human', 'composition subset is "human"');

    $f = npg_tracking::glossary::composition::factory->new();
    $f->add_component($comp3);
    $f->add_component($comp4);
    $c->{'subset'} = 'phix';
    $f->add_component(
      npg_tracking::glossary::composition::component::illumina->new($c)
    );

    $r = npg_qc::autoqc::results::result->new(composition => $f->create_composition());
    throws_ok {$r->composition_subset()} qr/Multiple subsets within the composition/,
      'error for multiple subsets';
}

{
    my $r = npg_qc::autoqc::results::result->new(id_run => 2, path => q[mypath], position => 1, tag_index => 4,);
    is($r->tag_index, 4, 'tag index set');
    lives_ok {npg_qc::autoqc::results::result->new(id_run => 2, path => q[mypath], position => 1, tag_index => 4,)}
       'can pass undef for tag_index in the constructor';
}

{
    my $r = npg_qc::autoqc::results::result->new(
                                        position  => 3,
                                        path      => 't/data/autoqc/090721_IL29_2549/data',
                                        id_run    => 2549,
                                                 );
    my $saved_path = q[/tmp/autoqc_check.json];
    $r->store($saved_path);
    delete $r->{'filename_root'};
    my $saved_r = npg_qc::autoqc::results::result->load($saved_path);
    sleep 1;
    unlink $saved_path;
    is_deeply($r, $saved_r, 'serialization to JSON file');
}

{
    my $r = npg_qc::autoqc::results::result->new(
                                        position  => 3,
                                        path      => 't/data/autoqc/090721_IL29_2549/data',
                                        id_run    => 2549,
                                                 );
    throws_ok {$r->equals_byvalue({})} qr/No parameters for comparison/, 'error when an empty hash is given in equals_byvalue';
    throws_ok {$r->equals_byvalue({position => 3, unknown => 5,})}
      qr/Can't locate object method \"unknown\"/,
     'error when a hash representing an unknown attribute is used in equals_byvalue';
    ok($r->equals_byvalue({position => 3, id_run => 2549,}), 'equals_byvalue returns true');
    ok($r->equals_byvalue({position => 3, class_name => q[result],}), 'equals_byvalue returns true');
    ok($r->equals_byvalue({position => 3, check_name => q[result], tag_index => undef,}), 'equals_byvalue returns true');
    ok(!$r->equals_byvalue({position => 3, check_name => q[result], tag_index => 0,}), 'equals_byvalue returns false');
    ok(!$r->equals_byvalue({position => 3, check_name => q[result], tag_index => 1,}), 'equals_byvalue returns false');
    ok(!$r->equals_byvalue({position => 3, class_name => q[insert_size],}), 'equals_byvalue returns false');    
}

{
    my $r = npg_qc::autoqc::results::result->new(
                                        position  => 3,
                                        id_run    => 2549,
                                        tag_index => 5,
                                                 );
    ok($r->equals_byvalue({position => 3, id_run => 2549, tag_index => 5, }), 'equals_byvalue returns true');
    ok($r->equals_byvalue({position => 3, class_name => q[result],}), 'equals_byvalue returns true');
    ok(!$r->equals_byvalue({position => 3, check_name => q[result], tag_index => undef,}), 'equals_byvalue returns false');
    ok(!$r->equals_byvalue({position => 3, check_name => q[result], tag_index => 0,}), 'equals_byvalue returns false');
    ok(!$r->equals_byvalue({position => 3, check_name => q[result], tag_index => 1,}), 'equals_byvalue returns false'); 
}

{
    my $r = npg_qc::autoqc::results::result->new(
                                        position  => 3,
                                        id_run    => 2549,
                                                );
    $r->set_info('Aligner', 'bwa-0.55');
    $r->set_info('Check', 'npg_qc::autoqc::check::sequence_error-7766');
    is($r->get_info('Aligner'), 'bwa-0.55', 'aligner version number stored');
    is($r->get_info('Check'), 'npg_qc::autoqc::check::sequence_error-7766', 'check version number stored')
}

{
    my $r = npg_qc::autoqc::results::result->new(
                                        position  => 3,
                                        id_run    => 2549,
                                                 );
    is ($r->rpt_key, q[2549:3], 'rpt key');
    
    $r = npg_qc::autoqc::results::result->new(
                                        position  => 3,
                                        id_run    => 2549,
                                        tag_index => 0
                                             );
    is ($r->rpt_key, q[2549:3:0], 'rpt key');

    $r = npg_qc::autoqc::results::result->new(
                                        position  => 3,
                                        id_run    => 2549,
                                        tag_index => 3
                                             );
    is ($r->rpt_key, q[2549:3:3], 'rpt key');      
}

{
    throws_ok {npg_qc::autoqc::results::result->inflate_rpt_key(q[5;6])}
        qr/Both id_run and position should be defined non-zero values /,
        'error when inflating rpt key';
    is_deeply(npg_qc::autoqc::results::result->inflate_rpt_key(q[5:6]), {id_run=>5,position=>6,}, 'rpt key inflated');
    is_deeply(npg_qc::autoqc::results::result->inflate_rpt_key(q[5:6:1]), {id_run=>5,position=>6,tag_index=>1}, 'rpt key inflated');
    is_deeply(npg_qc::autoqc::results::result->inflate_rpt_key(q[5:6:0]), {id_run=>5,position=>6,tag_index=>0}, 'rpt key inflated');
}

{
  my $f = npg_tracking::glossary::composition::factory->new();
  my $c = {id_run => 3, position => 4, tag_index => 5};
  my $comp1 = npg_tracking::glossary::composition::component::illumina->new($c);
  $f->add_component($comp1);
  $c->{'position'} = 5;
  my $comp2 = npg_tracking::glossary::composition::component::illumina->new($c);
  $f->add_component($comp2);
  my $r = npg_qc::autoqc::results::result->new(composition => $f->create_composition());
  ok($r->can('result_file_path'), 'object has result_file_path accessor');
  is($r->result_file_path, undef, 'value undefined by default');
  lives_ok { $r->result_file_path('my path') } 'can assign a value';
  is($r->result_file_path, 'my path', 'value was assigned correctly');
}
