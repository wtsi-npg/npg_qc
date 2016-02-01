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
      var rptKeys = mqc_outcomes.parseRptKeys('results_summary');
      var expected = ['18245:1', '18245:1:1', '18245:1:2','19001:1', '19001:1:1', '19001:1:2'];
      assert.deepEqual(rptKeys, expected, 'Correct rpt keys');
    });

    QUnit.test('Updating seq outcomes Accepted final', function(assert) {
      var qcOutcomes = {"lib":{},"seq":{"18245:1":{"mqc_outcome":"Accepted final","position":"1","id_run":"18245"}, "19001:1": {}}};
      var lanes = 0, lanesWithClass = 0;
      $('tr[id*="rpt_key:18245:1"] td.lane').each(function (i, obj) {
        lanes++;
        var $obj = $(obj);
        if ($obj.hasClass('passed')) {
          lanesWithClass++;
        }
      });
      assert.equal(lanes, 3, 'Correct number of lanes');
      assert.equal(lanesWithClass, 0, 'Initially lanes have no class');

      lanes =0; lanesWithClass = 0;
      mqc_outcomes.updateDisplayQCOutcomes(qcOutcomes);
      $('tr[id*="rpt_key:18245:1"] td.lane').each(function (i, obj) {
        lanes++;
        var $obj = $(obj);
        if ($obj.hasClass('passed')) {
          lanesWithClass++;
        }
      });
      assert.equal(lanes, 3, 'Correct number of lanes');
      assert.equal(lanesWithClass, 3, 'Correct number of lanes with updated class');

      lanes =0; lanesWithClass = 0;
      mqc_outcomes.updateDisplayQCOutcomes(qcOutcomes);
      $('tr[id*="rpt_key:19001:1"] td.lane').each(function (i, obj) {
        lanes++;
        var $obj = $(obj);
        if ($obj.hasClass('passed')) {
          lanesWithClass++;
        }
      });
      assert.equal(lanes, 3, 'Correct number of lanes');
      assert.equal(lanesWithClass, 0, 'Correct number of lanes with updated class');
    });
    
    QUnit.test('Test chainging the interface mocking ajax', function (assert) {
      expect(8);
      var old_ajax = $.ajax;
      $.ajax = function (options) {
        assert.equal(options.url, "/qcoutcomes", 'Correct request url');
        assert.equal(options.type, 'POST', 'Correct request type');
        assert.equal(options.contentType, 'application/json', 'Correct content type');
        var dataAsObject = JSON.parse(options.data);
        var expectedData = JSON.parse('{"18245:1":{},"18245:1:1":{},"18245:1:2":{},"19001:1":{},"19001:1:1":{},"19001:1:2":{}}');
        assert.deepEqual(dataAsObject, expectedData, 'Data in request is as expected');
        
        var data = {
          "lib":{},
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
        var rptKeys = mqc_outcomes.parseRptKeys('results_summary');
        var whatToDoWithOutcomes = function(data, textStatus, jqXHR) {
          var lanes = 0, lanesWithClass = 0;
          mqc_outcomes.updateDisplayQCOutcomes(data);
          $('tr[id*="rpt_key:18245:1"] td.lane').each(function (i, obj) {
            lanes++;
            var $obj = $(obj);
            if ($obj.hasClass('passed')) {
              lanesWithClass++;
            }
          });
          assert.equal(lanes, 3, 'Correct number of lanes');
          assert.equal(lanesWithClass, 3, 'Correct number of lanes with new class');
        };
        
        $('tr[id*="rpt_key:18245:1"] td.lane').each(function (i, obj) {
          lanes++;
          var $obj = $(obj);
          if ($obj.hasClass('passed')) {
            lanesWithClass++;
          }
        });
        assert.equal(lanes, 3, 'Correct number of lanes');
        assert.equal(lanesWithClass, 0, 'Initially lanes have no class');

        mqc_outcomes.fetchMQCOutcomes(rptKeys, '/qcoutcomes', whatToDoWithOutcomes);
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

