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
  'scripts/qcoutcomes/qc_css_styles',
  'scripts/qcoutcomes/manual_qc', 
  'scripts/qcoutcomes/qc_utils',
  '../../t/client/test_fixtures'
], function(qc_outcomes, qc_css_styles, NPG, qc_utils, fixtures) {

    QUnit.test('Parsing RPT keys', function (assert) {
      var rptKeys = qc_outcomes._parseRptKeys('results_summary');
      var expected = ['18245:1', '18245:1:1', '18245:1:2','19001:1', '19001:1:1', '19001:1:2'];
      assert.deepEqual(rptKeys, expected, 'Correct rpt keys');
    });

    QUnit.test('Updating seq outcomes Accepted final', function(assert) {
      var qcOutcomes = {"lib":{},"seq":{"18245:1":{"mqc_outcome":"Accepted final","position":"1","id_run":"18245"}}};
      var rows = 0, lanesWithClass = 0;
      $('tr[id*="rpt_key:18245:1"] td.lane').each(function (i, obj) {
        rows++;
        var $obj = $(obj);
        if ($obj.hasClass('qc_outcome_accepted_final')) {
          lanesWithClass++;
        }
      });
      assert.equal(rows, 3, 'Correct number of rows');
      assert.equal(lanesWithClass, 0, 'Initially lanes have no class');

      rows = 0; lanesWithClass = 0;
      $('tr[id*="rpt_key:19001:1"] td.lane').each(function (i, obj) {
        rows++;
        var $obj = $(obj);
        if ($obj.hasClass('qc_outcome_accepted_final')) {
          lanesWithClass++;
        }
      });
      assert.equal(rows, 3, 'Correct number of lanes');
      assert.equal(lanesWithClass, 0, 'Correct initial number of 190001 lanes with class different run');

      rows = 0; lanesWithClass = 0;
      qc_outcomes._updateDisplayWithQCOutcomes(qcOutcomes);
      $('tr[id*="rpt_key:18245:1"] td.lane').each(function (i, obj) {
        rows++;
        var $obj = $(obj);
        if ($obj.hasClass('qc_outcome_accepted_final')) {
          lanesWithClass++;
        }
      });
      assert.equal(rows, 3, 'Correct number of lanes');
      assert.equal(lanesWithClass, 3, 'Correct number of lanes with updated class');

      rows = 0; lanesWithClass = 0;
      qc_outcomes._updateDisplayWithQCOutcomes(qcOutcomes);
      $('tr[id*="rpt_key:19001:1"] td.lane').each(function (i, obj) {
        rows++;
        var $obj = $(obj);
        if ($obj.hasClass('qc_outcome_accepted_final')) {
          lanesWithClass++;
        }
      });
      assert.equal(rows, 3, 'Correct number of lanes');
      assert.equal(lanesWithClass, 0, 'Correct number of lanes with updated class different run');
    });

    QUnit.test('Updating lib outcomes Accepted final', function(assert) {
      var qcOutcomes = {"lib":{"18245:1:1":{"tag_index":1,"mqc_outcome":"Accepted final","position":"1","id_run":"18245"}},
                        "seq":{}};
      var rows = 0, elementsWithClass = 0;
      $('tr[id*="rpt_key:18245:1"] td.tag_info').each(function (i, obj) {
        rows++;
        var $obj = $(obj);
        if ($obj.hasClass('qc_outcome_accepted_final')) {
          elementsWithClass++;
        }
      });
      assert.equal(rows, 3, 'Correct number of rows');
      assert.equal(elementsWithClass, 0, 'Initially tags have no class');

      rows = 0; elementsWithClass = 0;
      qc_outcomes._updateDisplayWithQCOutcomes(qcOutcomes);
      $('tr[id*="rpt_key:18245:1"] td.tag_info').each(function (i, obj) {
        rows++;
        var $obj = $(obj);
        if ($obj.hasClass('qc_outcome_accepted_final')) {
          elementsWithClass++;
        }
      });
      assert.equal(rows, 3, 'Correct number of rows');
      assert.equal(elementsWithClass, 1, 'Correct number of tags with updated class');
      $('#rpt_key\\3A 18245\\3A 1\\3A 1 td.tag_info').each(function (i, obj) {
        var $obj = $(obj);
        assert.ok($obj.hasClass('qc_outcome_accepted_final'), 'rpt key has correct outcome');
      });

      rows = 0; elementsWithClass = 0;
      qc_outcomes._updateDisplayWithQCOutcomes(qcOutcomes);
      $('tr[id*="rpt_key:19001:1"] td.tag_info').each(function (i, obj) {
        rows++;
        var $obj = $(obj);
        if ($obj.hasClass('qc_outcome_accepted_final')) {
          elementsWithClass++;
        }
      });
      assert.equal(rows, 3, 'Correct number of rows');
      assert.equal(elementsWithClass, 0, 'Correct number of tags with updated class different run');
    });

    QUnit.test('Test changing the interface mocking ajax', function (assert) {
      assert.expect(10);
      var old_ajax = $.ajax;
      $.ajax = function (options) {
        assert.equal(options.url, "/qcoutcomes", 'Correct request url');
        assert.equal(options.type, 'POST', 'Correct request type');
        assert.equal(options.contentType, 'application/json', 'Correct content type');
        var dataAsObject = JSON.parse(options.data);
        var expectedData = JSON.parse('{"18245:1":{},"18245:1:1":{},"18245:1:2":{},"19001:1":{},"19001:1:1":{},"19001:1:2":{}}');
        assert.deepEqual(dataAsObject, expectedData, 'Data in request is as expected');

        var data = {
          "lib":{ "19001:1:2":{ "tag_index":2,"mqc_outcome":"Rejected preliminary","position":"1","id_run":"19001" } },
          "seq":{ "18245:1":{ "mqc_outcome":"Accepted final", "position":1, "id_run":18245 } }
        };
        options.success = function (callback) {
          callback(data, 'success', {});
          return options;
        };
        options.error = function () { return options; };
        return options;
      };

      try {
        var lanes = 0, lanesWithClass = 0;
        var whatToDoWithOutcomes = function() {
          var lanes = 0, lanesWithClass = 0;
          $('tr[id*="rpt_key:18245:1"] td.lane').each(function (i, obj) {
            lanes++;
            if ($(obj).hasClass('qc_outcome_accepted_final')) {
              lanesWithClass++;
            }
          });
          assert.equal(lanes, 3, 'Correct number of lanes');
          assert.equal(lanesWithClass, 3, 'Correct number of lanes with new class');
          var tags = 0, elementsWithClass = 0;
          $('tr[id*="rpt_key:19001:1"]  td.tag_info').each(function (i, obj) {
            tags++;
            if ($(obj).hasClass('qc_outcome_rejected_preliminary')) {
              elementsWithClass++;
            }
          });
          assert.equal(tags, 3, 'Correct number of tags');
          assert.equal(elementsWithClass, 1, 'Correct number of tags with new class');
        };

        $('tr[id*="rpt_key:18245:1"] td.lane').each(function (i, obj) {
          lanes++;
          if ($(obj).hasClass('qc_outcome_accepted_final')) {
            lanesWithClass++;
          }
        });
        assert.equal(lanes, 3, 'Correct number of lanes');
        assert.equal(lanesWithClass, 0, 'Initially lanes have no class');

        qc_outcomes.fetchAndProcessQC('results_summary', '/qcoutcomes', whatToDoWithOutcomes);
      } catch (err) {
        console.log(err);
      } finally {
        $.ajax = old_ajax;
      }
    });

    QUnit.test("Updating seq and lib outcomes for sample page", function (assert) {
      var _classNames = 'qc_outcome_accepted_final qc_outcome_accepted_preliminary qc_outcome_rejected_final qc_outcome_rejected_preliminary qc_outcome_undecided qc_outcome_undecided_final'.split(' ');
      var countQCClasses = function (obj) {
        var qcClasses = 0;
        for(var j = 0; j < _classNames.length; j++) {
          if(obj.hasClass(_classNames[j])) {
            qcClasses++;
          }
        }
        return qcClasses;
      };

      $('#results_summary').empty().append($('#fixture_sample_data').first().html());
      $('#fixture_sample_data').empty();

      var qcOutcomes = {"lib":{"19100:1:1":{"tag_index":1,"mqc_outcome":"Accepted final","position":"1","id_run":"19100"},
                               "19100:1:2":{"tag_index":2,"mqc_outcome":"Rejected final","position":"1","id_run":"19100"},
                               "19101:1:1":{"tag_index":1,"mqc_outcome":"Undecided","position":"1","id_run":"19101"}},
                        "seq":{"19100:1":{"mqc_outcome":"Accepted final","position":"1","id_run":"19100"}}};
      var rows = 0, elementsWithClass = 0,
          totalQCClasses = 0, expected = ['accepted_final', 'rejected_final'];
      //19100
      $('tr[id*="rpt_key:19100:1"] td.tag_info').each(function (i, obj) {
        rows++;
        totalQCClasses += countQCClasses($(obj));
      });
      assert.equal(rows, 2, 'Correct number of rows');
      assert.equal(totalQCClasses, 0, 'Initially tags without classes for run 19100');

      rows = 0; elementsWithClass = 0; totalQCClasses = 0;
      $('tr[id*="rpt_key:19100:1"] td.lane').each(function (i, obj) {
        rows++;
        totalQCClasses += countQCClasses($(obj));
      });
      assert.equal(rows, 2, 'Correct number of rows');
      assert.equal(totalQCClasses, 0, 'Initially lanes without classes for run 19100');

      //19101
      rows = 0; elementsWithClass = 0; totalQCClasses = 0;
      $('tr[id*="rpt_key:19101:1"] td.tag_info').each(function (i, obj) {
        rows++;
        totalQCClasses += countQCClasses($(obj));
      });
      assert.equal(rows, 1, 'Correct number of rows');
      assert.equal(totalQCClasses, 0, 'Initially tags without classes for run 19101');

      rows = 0; elementsWithClass = 0; totalQCClasses = 0;
      $('tr[id*="rpt_key:19101:1"] td.lane').each(function (i, obj) {
        rows++;
        totalQCClasses += countQCClasses($(obj));
      });
      assert.equal(rows, 1, 'Correct number of rows');
      assert.equal(elementsWithClass, 0, 'Initially lanes without classes for run 19101');

      qc_outcomes._updateDisplayWithQCOutcomes(qcOutcomes);

      //19100
      rows = 0; elementsWithClass = 0;
      $('tr[id*="rpt_key:19100:1"] td.tag_info').each(function (i, obj) {
        rows++;
        if ($(obj).hasClass('qc_outcome_' + expected[i]) &&
            countQCClasses($(obj)) == 1 ) {
          elementsWithClass++;
        }
      });
      assert.equal(rows, 2, 'Correct number of rows');
      assert.equal(elementsWithClass, 2, 'Correct number of tags with updated class for run 19100');

      rows = 0; elementsWithClass = 0;
      $('tr[id*="rpt_key:19100:1"] td.lane').each(function (i, obj) {
        rows++;
        if ($(obj).hasClass('qc_outcome_accepted_final') &&
            countQCClasses($(obj)) == 1 ) {
          elementsWithClass++;
        }
      });
      assert.equal(rows, 2, 'Correct number of rows');
      assert.equal(elementsWithClass, 2, 'Correct number of lanes with updated class for run 19100');

      //19101
      rows = 0; elementsWithClass = 0;
      $('tr[id*="rpt_key:19101:1"] td.tag_info').each(function (i, obj) {
        rows++;
        if ($(obj).hasClass('qc_outcome_undecided') &&
            countQCClasses($(obj)) == 1 ) {
          elementsWithClass++;
        }
      });
      assert.equal(rows, 1, 'Correct number of rows');
      assert.equal(elementsWithClass, 1, 'Correct number of tags without new class for run 19101');

      rows = 0; elementsWithClass = 0;
      $('tr[id*="rpt_key:19101:1"] td.lane').each(function (i, obj) {
        rows++;
        if ($(obj).hasClass('qc_outcome_undecided') &&
            countQCClasses($(obj)) == 1 ) {
          elementsWithClass++;
        }
      });
      assert.equal(rows, 1, 'Correct number of rows');
      assert.equal(elementsWithClass, 0, 'Correct number of lanes with new class for run 19101');
    });

    QUnit.test("QC outcomes map to css styles", function (assert) {
      var element = $('<div></div>');
      assert.throws(
        function () { qc_css_styles.displayElementAs(element, 'Accepted maybe'); },
        /corresponding style for QC outcome/,
        'Throws exception for unknown QC outcome'
      );
      assert.ok(!element.hasClass('qc_outcome_accepted_preliminary'), 'Without class before call');
      qc_css_styles.displayElementAs(element, 'Accepted preliminary');
      assert.ok(element.hasClass('qc_outcome_accepted_preliminary'), 'With class after call');
      qc_css_styles.displayElementAs(element, 'Rejected final');
      assert.ok(element.hasClass('qc_outcome_rejected_final') &&
                !element.hasClass('qc_outcome_accepted_preliminary'), 'Replaced class after call');
      try {
        qc_css_styles.displayElementAs(element, 'Accepted maybe');
      } catch(er) {
        assert.ok(element.hasClass('qc_outcome_rejected_final'),
          'Does not remove old class unless new class is valid.');
      }
    });

    QUnit.test('Updating for a non-existing element', function(assert) {
      var qcOutcomes = {"seq":{"18245:1":{"mqc_outcome":"Rejected final"},
                               "19001:1":{"mqc_outcome":"Accepted final"},
                               "1824500:1":{"mqc_outcome":"Accepted final"}}};
      var procOut = qc_outcomes._processOutcomes(qcOutcomes.seq, 'mqc_outcome',  'lane');     
      var expected = {"18245:1":1,"19001:1":1,"1824500:1":0};
      assert.deepEqual(procOut, expected, 
        'processOutcomes reports expected hash with 2 existing and one absent element');
    });                    

    QUnit.test("Parameter validation tests for _selectionForKey", function (assert) {
      assert.throws(
        function() {
          qc_outcomes._selectionForKey();
        },
        /Both key and elementClass are required/i,
        'Error with no params'
      );
      assert.throws(
        function() {
          qc_outcomes._selectionForKey('18245:1');
        },
        /Both key and elementClass are required/i,
        'Error with only key param'
      );
      assert.throws(
        function() {
          qc_outcomes._selectionForKey('lane');
        },
        /Both key and elementClass are required/i,
        'Error with only elementClass param'
      );
      
      var selection = qc_outcomes._selectionForKey('18245:1','lane',true);
      assert.equal(selection.length, 3, 
        "fuzzy _selectionForKey returns 3 objects for 'lane' 18245:1");
      selection = qc_outcomes._selectionForKey('18245:1:2','tag_info',false);
      assert.equal(selection.length, 1, 
        "exact match _selectionForKey returns 1 object for 'tag_info' 18245:1:2"); 
    });

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
           /Malformed QC outcomes data/i,
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
      assert.deepEqual(qc_outcomes._processOutcomes( {"18245:1":{"uqc_outcome":"Accepted"}}, 'uqc_outcome', 'lane'), 
        {"18245:1": 1},
        '__processOutcomes reports existing element for "18245:1"');
      assert.deepEqual(qc_outcomes._processOutcomes( {"19001:1":{"uqc_outcome":"Rejected"}}, 'uqc_outcome', 'lane'), 
        {"19001:1": 1},
        '__processOutcomes reports existing element for "19001:1"');
      assert.deepEqual(qc_outcomes._processOutcomes( {"1824500:1":{"uqc_outcome":"Accepted"}}, 'uqc_outcome', 'lane'), 
        {"1824500:1": 0},
        '__processOutcomes reports no existing element for "1824500:1"');
      
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

    QUnit.test("Clickable UQC link ", function (assert) {
      $("#qunit-fixture").prepend("<ul id='ajax_status'></ul>");
      var $UQC_LINK_PLACEHOLDER = $("#summary_to_csv").parent().parent() ;
      assert.equal($UQC_LINK_PLACEHOLDER.length, 0, 'No $UQC_LINK_PLACEHOLDER');

      var callback = function() {return true;};
      NPG.QC.addUQCLink (callback);
      assert.equal(
                  $("#ajax_status .failed_mqc").text(),
                  "The UQC Link could not be added. The Link\'s placeholder could not be found.",
                  "Warns when the UQC Link placeholder is not found"
                  );

      var page_fixture = fixtures.fixtures_menu_links;
      var nbUQCLinks = $("#uqcClickable").length;
      var MENU_PLACEHODER = "#menu #links";
      $('#qunit-fixture').after(page_fixture);
      $UQC_LINK_PLACEHOLDER = $("#summary_to_csv").parent().parent() ;
      assert.equal($UQC_LINK_PLACEHOLDER.length, 1, 'UQC_LINK_PLACEHOLDER is present');
      assert.throws(
                    function() {
                      NPG.QC.addUQCLink ();
                    },
                    /A defined callback function is required as parameter/, 
                    "Throws when no callback function is passed"
                    );

      callback = 3;
      assert.throws(
                    function() {
                      NPG.QC.addUQCLink (callback);
                    },
                     /A defined callback function is required as parameter/, 
                     "Throws when callback is not a function");

      assert.equal(nbUQCLinks, 0, 'No preexisting annotation Link');
      NPG.QC.addUQCLink (function() {});
      nbUQCLinks = $(" #uqcClickable").length;
      assert.equal(nbUQCLinks, 1, 'Annotation Link present after call');
      nbUQCLinks = $( MENU_PLACEHODER + " #uqcClickable").length;
      assert.equal(nbUQCLinks, 1, 'Annotation Link is at the expected container');
      
      $('#uqcClickable').trigger('click');
      nbUQCLinks = $("#uqcClickable").length;
      assert.equal(nbUQCLinks, 0, 'Annotation Link is removed after clicking on it');

      $("#fixture_sample_data").remove();
      var plexesRows = [
        "18245:1:1",
        "18245:1:2",
        "19001:1:1",
        "19001:1:2"
      ];

      plexesRows.forEach(function(targetId) {
        $(qc_utils.buildIdSelectorFromRPT(targetId)).remove();
      });
  
      var laneRows = [
        "18245:1",
        "19001:1"
      ];
      laneRows.forEach(function(targetId) {      
        assert.equal($(qc_utils.buildIdSelectorFromRPT(targetId)).closest("tr").find('img[alt="link to tags"]').length , 1, 
          targetId + 'has children and therefore is not uqc_able');
      });
      var calledOnClick = false;
      callback = function () {
                   calledOnClick = true;
                };
      NPG.QC.addUQCLink (callback);
      $('#uqcClickable').trigger('click');
      assert.ok(!calledOnClick, 'Instead of callback(), warning appears when page only have no uqc_able lanes');
    });

    QUnit.test("Passing a uqc_outcome to a non mqc element does not mark for UQC writing", function (assert) {
      var page_fixture = fixtures.fixtures_menu_links;
      var MQC_ABLE_CLASS = '.lane_mqc_control';
      var UQC_CONTROL_CLASS = 'uqc_control';
      var qcOutcomes = {"lib":{},
                        "uqc":{"19001:1":{"uqc_outcome":"Accepted"}},
                        "seq":{}};

      $("#fixture_sample_data").remove();
      $('#qunit-fixture').after(page_fixture);                 
      NPG.QC.addUQCLink (
                        function() {
                          NPG.QC.launchUtilityQCProcesses(true, qcOutcomes, '/someUrl');
                        });
      var nbOfMQCAbleElements = $(MQC_ABLE_CLASS).length;
      assert.equal(nbOfMQCAbleElements, 6, '6 MQC markup present initially');
      $(qc_utils.buildIdSelectorFromRPT("19001:1:1") + " " + MQC_ABLE_CLASS).remove();
      nbOfMQCAbleElements = $(MQC_ABLE_CLASS).length;
      assert.equal(nbOfMQCAbleElements, 5, '5 MQC markup present after removing mark in 19001:1:1');

      $('#uqcClickable').click();
      var nbOfUQCMarkedElements = 0;
      $(qc_utils.buildIdSelectorFromRPT("19001:1:1") + " ." + UQC_CONTROL_CLASS).each(function() {
        nbOfUQCMarkedElements++;
      });
      assert.equal(nbOfUQCMarkedElements, 0, '19001:1:1 is not UQC marked' );

      [
        "18245:1:1",
        "18245:1:2",
        "19001:1:2"
      ].forEach(function(targetId) {
        var targetIsMarked = ($(qc_utils.buildIdSelectorFromRPT(targetId)  + ' .' + UQC_CONTROL_CLASS).length === 1);
        assert.ok(targetIsMarked,'UQC Mark is defined for key :' + targetId);
      }); 
    });

    QUnit.test("Passing a uqc_outcome to a non qc-able element should not mark for UQC writing",
     function (assert) {
      var page_fixture = fixtures.fixtures_menu_links;
      var MQC_ABLE_CLASS = '.lane_mqc_control';
      var UQC_CONTROL_CLASS = 'uqc_control';
      var qcOutcomes = {"lib":{},
                        "uqc":{"19001:1":{"uqc_outcome":"Accepted"},
                               "18245:1":{"uqc_outcome":"Rejected"}},
                        "seq":{}};

      $("#fixture_sample_data").remove();
      $('#qunit-fixture').after(page_fixture);
      NPG.QC.addUQCLink (
                         function() {
                           NPG.QC.launchUtilityQCProcesses(true, qcOutcomes, '/someUrl');
                         });
       
      var uqcAbleElements = [];
      var uqcInd = 0;
      var nonUqcAbleElements = [];
      var nonUqcInd = 0;

      $(MQC_ABLE_CLASS).each(function (index, element) {
        var isElementUQCable = NPG.QC.isElementUQCable(element);
        if (isElementUQCable){
          uqcAbleElements[uqcInd++] = qc_utils.rptKeyFromId($(element).closest('tr').attr('id'));
        } else {
          nonUqcAbleElements[nonUqcInd++] = qc_utils.rptKeyFromId($(element).closest('tr').attr('id'));
        }
      });
      $('#uqcClickable').click();

      uqcAbleElements.forEach(function(rpt_key) {
        var idSelectorFromRPT = qc_utils.buildIdSelectorFromRPT(rpt_key);
        var targetIsMarked = ($(idSelectorFromRPT + ' .' + UQC_CONTROL_CLASS).length === 1);
        assert.ok(targetIsMarked, rpt_key + ' is marked for uqc writing');
      });

      nonUqcAbleElements.forEach(function(rpt_key) {
        var idSelectorFromRPT = qc_utils.buildIdSelectorFromRPT(rpt_key);
        var targetIsMarked = ($(idSelectorFromRPT + ' .' + UQC_CONTROL_CLASS).length === 1);
        assert.ok(!targetIsMarked, rpt_key + ' is not marked for uqc writing');
      });
       
    });

    QUnit.test("Identifying uqc-able elements", function (assert) {
      var page_fixture = fixtures.fixtures_menu_links;
      var MQC_ABLE_CLASS = '.lane_mqc_control';
      var UQC_CONTROL_CLASS = 'uqc_control';
      var COLOURS_RGB = {
        RED:   'rgb(255, 0, 0)',
        GREEN: 'rgb(0, 128, 0)',
        GREY:  'rgb(128, 128, 128)',
      };
      var qcOutcomes = {"lib":{},
                        "uqc":{"18245:1:1":{"uqc_outcome":"Rejected"},
                               "18245:1:2":{"uqc_outcome":"Accepted"},
                               "19001:1:1":{"uqc_outcome":"Undecided"},},
                        "seq":{}};

      $("#fixture_sample_data").remove();
      $('#qunit-fixture').after(page_fixture);
      NPG.QC.addUQCLink (
                         function() {
                           NPG.QC.launchUtilityQCProcesses(true, qcOutcomes, '/someUrl');
                         });
      var nbOfMQCAbleElements = $(MQC_ABLE_CLASS).length;
      assert.equal(nbOfMQCAbleElements, 6, '6 markup present initially');
      $('#uqcClickable').trigger('click');
      

      var expectedColours = [
        COLOURS_RGB.RED,
        COLOURS_RGB.GREEN,
        COLOURS_RGB.GREY,
        COLOURS_RGB.GREY
      ];

      [
        "18245:1:1",
        "18245:1:2",
        "19001:1:1",
        "19001:1:2"
      ].forEach(function(targetId, index) {
        var $element = $($(qc_utils.buildIdSelectorFromRPT(targetId) + ' .' + UQC_CONTROL_CLASS)[0]);
        assert.ok(typeof $element.css("background-color") !== 'undefined','colour is defined for ' + targetId);
        assert.equal(
          $element.css("background-color"),
          expectedColours[index],
          'expected colour found'
        ); 
      });
    });    

    // run the tests.
    QUnit.start();
  }
);

