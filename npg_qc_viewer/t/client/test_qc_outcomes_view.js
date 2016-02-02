"use strict";
require.config({
  baseUrl: '../../root/static',
  paths: {
    jquery: 'bower_components/jquery/dist/jquery',
  },
});

require(['scripts/qc_outcomes_view',],
  function(mqc_outcomes) {
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
      mqc_outcomes._updateDisplayQCOutcomes(qcOutcomes);
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
      mqc_outcomes._updateDisplayQCOutcomes(qcOutcomes);
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
      var rows = 0, tagsWithClass = 0;
      $('tr[id*="rpt_key:18245:1"] td.tag_info').each(function (i, obj) {
        rows++;
        var $obj = $(obj);
        if ($obj.hasClass('qc_outcome_accepted_final')) {
          tagsWithClass++;
        }
      });
      assert.equal(rows, 3, 'Correct number of rows');
      assert.equal(tagsWithClass, 0, 'Initially tags have no class');

      rows = 0; tagsWithClass = 0;
      mqc_outcomes._updateDisplayQCOutcomes(qcOutcomes);
      $('tr[id*="rpt_key:18245:1"] td.tag_info').each(function (i, obj) {
        rows++;
        var $obj = $(obj);
        if ($obj.hasClass('qc_outcome_accepted_final')) {
          tagsWithClass++;
        }
      });
      assert.equal(rows, 3, 'Correct number of rows');
      assert.equal(tagsWithClass, 1, 'Correct number of tags with updated class');
      $('#rpt_key\\3A 18245\\3A 1\\3A 1 td.tag_info').each(function (i, obj) {
        var $obj = $(obj);
        assert.ok($obj.hasClass('qc_outcome_accepted_final'), 'rpt key has correct outcome');
      });

      rows = 0; tagsWithClass = 0;
      mqc_outcomes._updateDisplayQCOutcomes(qcOutcomes);
      $('tr[id*="rpt_key:19001:1"] td.tag_info').each(function (i, obj) {
        rows++;
        var $obj = $(obj);
        if ($obj.hasClass('qc_outcome_accepted_final')) {
          tagsWithClass++;
        }
      });
      assert.equal(rows, 3, 'Correct number of rows');
      assert.equal(tagsWithClass, 0, 'Correct number of tags with updated class different run');
    });

    QUnit.test('Test chainging the interface mocking ajax', function (assert) {
      expect(10);
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
        options.error = function (callback) { return options; };
        return options;
      };

      try {
        var lanes = 0, lanesWithClass = 0;
        var whatToDoWithOutcomes = function(data, textStatus, jqXHR) {
          var lanes = 0, lanesWithClass = 0;
          $('tr[id*="rpt_key:18245:1"] td.lane').each(function (i, obj) {
            lanes++;
            if ($(obj).hasClass('qc_outcome_accepted_final')) {
              lanesWithClass++;
            }
          });
          assert.equal(lanes, 3, 'Correct number of lanes');
          assert.equal(lanesWithClass, 3, 'Correct number of lanes with new class');
          var tags = 0, tagsWithClass = 0;
          $('tr[id*="rpt_key:19001:1"]  td.tag_info').each(function (i, obj) {
            tags++;
            if ($(obj).hasClass('qc_outcome_rejected_preliminary')) {
              tagsWithClass++;
            }
          });
          assert.equal(tags, 3, 'Correct number of tags');
          assert.equal(tagsWithClass, 1, 'Correct number of tags with new class');
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

    // run the tests.
    QUnit.start();
  }
);

