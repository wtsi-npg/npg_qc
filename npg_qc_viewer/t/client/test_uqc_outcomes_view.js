/* globals $, QUnit, requirejs */
"use strict";
requirejs.config({
  baseUrl: '../../root/static',
  paths: {
    'qunit': 'bower_components/qunit/qunit/qunit',
    jquery:  'bower_components/jquery/dist/jquery'
  }
});

requirejs([
  'scripts/qcoutcomes/qc_outcomes_view',
  'scripts/qcoutcomes/qc_utils'
], function(qc_outcomes,
            qc_utils
) {  

    QUnit.test('Parsing RPT keys', function (assert) {
      var rptKeys = qc_outcomes._parseRptKeys('results_summary');
      var expected = ['18245:1', '18245:1:1', '18245:1:2','19001:1', '19001:1:1', '19001:1:2'];
      assert.deepEqual(rptKeys, expected, 'Correct rpt keys');
    });

    QUnit.test("Parameter validation tests for utilityDisplaySwitch", function (assert) {
      assert.throws(
        function() {
          qc_outcomes.utilityDisplaySwitch();
        },
        /Parameter obj must be defined and of type \(DOM\) Element/i,
        'Throws with no params'
      );
      assert.throws(
        function() {
          qc_outcomes.utilityDisplaySwitch(1);
        },
        /Parameter obj must be defined and of type \(DOM\) Element/i,
        'Throws with one (non DOM) param'
      );
      var some_element = $('td.lane')[0];
      assert.throws(
        function() {
          qc_outcomes.utilityDisplaySwitch(some_element);
        },
        /utility should be a string/i,
        'Throws with one param'
      );
      assert.throws(
        function() {
          qc_outcomes.utilityDisplaySwitch(some_element, true);
        },
        /utility should be a string/i,
        'Throws with non string parameter'
      );
    });

    QUnit.test('Trying to display an undefined uqc outcome', function(assert) {
      var qcOutcomes = {"lib":{},
                        "seq":{},
                        "uqc":{"19001:1":{}}};
      assert.throws(
        function() {
          qc_outcomes._updateDisplayWithQCOutcomes(qcOutcomes);
        },
           /Malformed QC outcomes data for 19001:1/i,
           'Throws with empty uqc_outcome'
      );
    }); 

    QUnit.test('Trying to display an unrecognized uqc outcome', function(assert) {
      var qcOutcomes = {"lib":{},
                        "seq":{},
                        "uqc":{"19001:1":{"uqc_outcome":"RandomOutcome"}}};
      assert.throws(
        function() {
          qc_outcomes._updateDisplayWithQCOutcomes(qcOutcomes);
        },
           /Invalid value/i,
           'Throws with invalid uqc_outcome'
      );
    }); 

    QUnit.test('Trying to display a non-existing rpt_key', function(assert) {
      var qcOutcomes = {"lib":{},
                        "seq":{"18245:1":{"mqc_outcome":"Rejected final"},
                               "19001:1":{"mqc_outcome":"Accepted final"}},
                        "uqc":{"18245:1":{"uqc_outcome":"Accepted"},
                               "19001:1":{"uqc_outcome":"Rejected"},
                               "1824500:1":{"uqc_outcome":"Accepted"}}};

      var rpt_keys = Object.keys(qcOutcomes.uqc);
      var received = {};
      for (var i in rpt_keys) {
        var key = rpt_keys[i];
        var elementClass = qc_utils.isLaneKey(key) ? 'lane' : 'tag_info';
        var arr = {};
        arr[key] = qcOutcomes.uqc[key];
        received[key] = qc_outcomes._processOutcomes( arr, 'uqc_outcome', elementClass)[key];
      }
      var expected = {"18245:1":1,"19001:1":1,"1824500:1":0};
      assert.deepEqual(received, expected, 
        '__processOutcomes reports expected hash with 2 existing and 1 absent element');
    }); 

    QUnit.test("utilityDisplaySwitch tests for fail/pass/undecided utility icon in LaneNo column", function (assert) {
      var laneCellsNumb = $('td.lane > a[href]').length;
      assert.equal(laneCellsNumb, 6, 'Correct number of .lane cells with <a> href');
      var total_icons_fails = $("td.lane > span.utility_fail").length;
      assert.equal(total_icons_fails, 0, 'No initial .lane cells with fail icons');

      $('td.lane').each(function (i, obj) {
        qc_outcomes.utilityDisplaySwitch(obj, 'Rejected');
      });
      total_icons_fails = $("td.lane > span.utility_fail").length;
      assert.equal(total_icons_fails, laneCellsNumb,
        '1 fail icon per .lane cell added with utilityDisplaySwitch()');
      
      var total_icons_pass = $("td.lane > span.utility_pass").length;
      assert.equal(total_icons_pass, 0,
        'No .lane cells with pass after all cells were switched to fail');
      $('td.lane').each(function (i, obj) {
        qc_outcomes.utilityDisplaySwitch(obj, 'Accepted');
      });
      total_icons_pass = $("td.lane > span.utility_pass").length;
      assert.equal(total_icons_pass, laneCellsNumb,
        '1 pass icon per .lane cell changed with utilityDisplaySwitch()');
      total_icons_fails = $("td.lane > span.utility_fail").length;
      assert.equal(total_icons_fails, 0,
        'No .lane cells with fail after all cells were switched to pass');
      
      $('td.lane').each(function (i, obj) {
        qc_outcomes.utilityDisplaySwitch(obj, 'Undecided');
      });
      var total_icons = $("td.lane > span.utility_fail").length + $("td.lane > span.utility_pass").length;
      assert.equal(total_icons, 0,
        'No icons after all cells changed to Undecided');
    });

    QUnit.test('Updating display uqc outcomes on plex', function(assert) {
      var qcOutcomes = {"lib":{"18245:1:1":{"mqc_outcome":"Accepted final"}},
                        "uqc":{"18245:1:1":{"uqc_outcome":"Rejected"}},
                        "seq":{}};
      var key = "18245:1:1";                  
      var rptKeyAsSelector = '#rpt_key\\3A ' + key.replace(/:/g, '\\3A ');
      var total_icons = $(rptKeyAsSelector + " td.tag_info > span.utility_fail").length + 
                        $(rptKeyAsSelector + " td.tag_info > span.utility_pass").length;
      assert.equal(total_icons, 0, 'Initially 18245:1:1 plex has not utility flag');
      
      qc_outcomes._updateDisplayWithQCOutcomes(qcOutcomes);
      total_icons = $(rptKeyAsSelector + " td.tag_info > span.utility_fail").length + 
                    $(rptKeyAsSelector + " td.tag_info > span.utility_pass").length;
      assert.equal(total_icons, 1, '18245:1:1 plex has utility flag');

      qcOutcomes = {"lib":{},
                        "uqc":{"18245:1:1":{"uqc_outcome":"Undecided"}},
                        "seq":{}};
      qc_outcomes._updateDisplayWithQCOutcomes(qcOutcomes);
      total_icons = $(rptKeyAsSelector + " td.tag_info > span.utility_fail").length + 
                    $(rptKeyAsSelector + " td.tag_info > span.utility_pass").length;
      assert.equal(total_icons, 0, '18245:1:1 plex has not a utility flag after updating to Undecided');
    });

    QUnit.test('Updating display uqc outcomes on lane', function(assert) {
      var qcOutcomes = {"lib":{},
                        "uqc":{"18245:1":{"uqc_outcome":"Rejected"},
                               "19001:1":{"uqc_outcome":"Accepted"}},
                        "seq":{}};

      var total_icons = $("tr[id*='rpt_key:18245'] td.lane > span.utility_fail").length + 
                        $("tr[id*='rpt_key:18245'] td.lane > span.utility_pass").length + 
                        $("tr[id*='rpt_key:19001'] td.lane > span.utility_fail").length + 
                        $("tr[id*='rpt_key:19001'] td.lane > span.utility_pass").length;

      assert.equal(total_icons, 0, 'Initially lanes have not utility flag');
      
      qc_outcomes._updateDisplayWithQCOutcomes(qcOutcomes);
      total_icons = $("tr[id*='rpt_key:18245'] td.lane > span.utility_fail").length + 
                    $("tr[id*='rpt_key:18245'] td.lane > span.utility_pass").length + 
                    $("tr[id*='rpt_key:19001'] td.lane > span.utility_fail").length + 
                    $("tr[id*='rpt_key:19001'] td.lane > span.utility_pass").length;
      assert.equal(total_icons, 2, '2 lanes have utility flag');

      qcOutcomes = {"lib":{},
                    "uqc":{"18245:1":{"uqc_outcome":"Accepted"},
                           "19001:1":{"uqc_outcome":"Undecided"}},
                    "seq":{}};              
      qc_outcomes._updateDisplayWithQCOutcomes(qcOutcomes);
      total_icons = $("tr[id*='rpt_key:18245'] td.lane > span.utility_fail").length + 
                    $("tr[id*='rpt_key:18245'] td.lane > span.utility_pass").length + 
                    $("tr[id*='rpt_key:19001'] td.lane > span.utility_fail").length + 
                    $("tr[id*='rpt_key:19001'] td.lane > span.utility_pass").length;
      assert.equal(total_icons, 1, 'only 1 lane has utility flag and 1 has Undecided outcome');
    });

    QUnit.test('Updating display uqc outcomes on lane and plex', function(assert) {
      var qcOutcomes = {"lib":{"18245:1:1":{"mqc_outcome":"Accepted final"}, 
                               "18245:1:2":{"mqc_outcome":"Rejected final"}},
                        "uqc":{"18245:1":{"uqc_outcome":"Rejected"},
                               "18245:1:1":{"uqc_outcome":"Accepted"}},
                        "seq":{"18245:1":{"mqc_outcome":"Accepted final"}}};

      var total_icons = $("tr[id*='rpt_key:18245'] td.lane > span.utility_fail").length + 
                        $("tr[id*='rpt_key:18245'] td.lane > span.utility_pass").length;
      assert.equal(total_icons, 0, 'Initially 18245 lanes have not utility flag');
      
      qc_outcomes._updateDisplayWithQCOutcomes(qcOutcomes);
      total_icons = $("tr[id*='rpt_key:18245'] td.lane > span.utility_fail").length + 
                    $("tr[id*='rpt_key:18245'] td.lane > span.utility_pass").length;
      assert.equal(total_icons, 1, '18245 lanes have 1 utility flag');
      
      total_icons = $("tr[id*='rpt_key:18245'] td.lane > span.utility_fail").length + 
                    $("tr[id*='rpt_key:18245'] td.lane > span.utility_pass").length;
      assert.equal(total_icons, 1, '18245 plexes have 1 utility flag');

    });

    // run the tests.
    QUnit.start();
  }
);
