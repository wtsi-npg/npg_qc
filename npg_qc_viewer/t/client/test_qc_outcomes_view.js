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
  'scripts/qcoutcomes/qc_css_styles'
], function(mqc_outcomes, qc_css_styles) {


    QUnit.test('Parsing RPT keys', function (assert) {
      var rptKeys = mqc_outcomes._parseRptKeys('results_summary');
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
      mqc_outcomes._updateDisplayWithQCOutcomes(qcOutcomes);
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
      mqc_outcomes._updateDisplayWithQCOutcomes(qcOutcomes);
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
      mqc_outcomes._updateDisplayWithQCOutcomes(qcOutcomes);
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
      mqc_outcomes._updateDisplayWithQCOutcomes(qcOutcomes);
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

    QUnit.test('Test chainging the interface mocking ajax', function (assert) {
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

        mqc_outcomes.fetchAndProcessQC('results_summary', '/qcoutcomes', whatToDoWithOutcomes);
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

      mqc_outcomes._updateDisplayWithQCOutcomes(qcOutcomes);

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

    QUnit.test("Parameter validation tests for usabilityDisplaySwitch", function (assert) {
      assert.throws(
        function() {
          mqc_outcomes.usabilityDisplaySwitch();
        },
        /Parameter obj must be defined and of type \(DOM\) Element/i,
        'Throws with no params'
      );
      assert.throws(
        function() {
          mqc_outcomes.usabilityDisplaySwitch(1);
        },
        /Parameter obj must be defined and of type \(DOM\) Element/i,
        'Throws with one (non DOM) param'
      );
      var some_element = $('td.lane')[0];
      assert.throws(
        function() {
          mqc_outcomes.usabilityDisplaySwitch(some_element);
        },
        /usability should be boolean/i,
        'Throws with one param'
      );
      assert.throws(
        function() {
          mqc_outcomes.usabilityDisplaySwitch(some_element, 'string');
        },
        /usability should be boolean/i,
        'Throws with one string instead of boolean'
      );
    });

    QUnit.test("Test for FAIL/PASS usability icon in LaneNo column", function (assert) {
      var laneCellsNumb = $('td.lane').length;
      assert.equal(laneCellsNumb, 9, 'Correct number of .lane cells');
      var total_icons_fails = $("td.lane > div.utility_FAIL").length;
      var total_icons_pass = $("td.lane > div.utility_PASS").length;
      assert.equal(total_icons_fails, 0, 'No initial .lane cells with FAIL icons');
      assert.equal(total_icons_pass, 0, 'No initial .lane cells with PASS icons');
      $('td.lane').each(function (i, obj) {
        mqc_outcomes.usabilityDisplaySwitch(obj, false);
      });
      $('td.lane.nbsp > div').each(function(i, obj){
        if($(obj).attr('class') === "utility_FAIL"){
          total_icons_fails++;
        }
      });
      assert.equal(total_icons_fails, laneCellsNumb,
        '1 FAIL icon per .lane cell added with usabilityDisplaySwitch()');
      total_icons_pass = $("td.lane > div.utility_PASS").length;
      assert.equal(total_icons_pass, 0,
        'No .lane cells with PASS after all cells were switched to FAIL');
      $('td.lane').each(function (i, obj) {
        mqc_outcomes.usabilityDisplaySwitch(obj, true);
      });
      $('td.lane.nbsp > div').each(function(i, obj){
        if($(obj).attr('class') === "utility_PASS"){
          total_icons_pass++;
        }
      });
      assert.equal(total_icons_pass, laneCellsNumb,
        '1 PASS icon per .lane cell changed with usabilityDisplaySwitch()');
      total_icons_fails = $("td.lane > div.utility_FAIL").length;
      assert.equal(total_icons_fails, 0,
        'No .lane cells with FAIL after all cells were switched to PASS');
    });

    // run the tests.
    QUnit.start();
  }
);

