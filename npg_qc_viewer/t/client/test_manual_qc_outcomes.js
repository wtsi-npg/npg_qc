"use strict";
require.config({
  baseUrl: '../../root/static',
  paths: {
    jquery: 'bower_components/jquery/dist/jquery',
  },
});

require(['scripts/manual_qc_outcomes',],
  function(mqc_outcomes) {
    QUnit.test('Parsing RPT keys', function (assert) {
      var rptKeys = mqc_outcomes.parseRptKeys('results_summary');
      var expected = ['18245:1', '18245:1:1', '18245:1:2','19001:1', '19001:1:1', '19001:1:2'];
      assert.deepEqual(rptKeys, expected, 'Correct rpt keys');
    });

    QUnit.test('Updating outcomes', function(assert) {
      var qcOutcomes = {"lib":{},"seq":{"18245:1":{"mqc_outcome":"Accepted final","position":"1","id_run":"18245"}}};
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
      mqc_outcomes.updateQCOutcomes(qcOutcomes);
      $('tr[id*="rpt_key:18245:1"] td.lane').each(function (i, obj) {
        lanes++;
        var $obj = $(obj);
        if ($obj.hasClass('passed')) {
          lanesWithClass++;
        }
      });
      assert.equal(lanes, 3, 'Correct number of lanes');
      assert.equal(lanesWithClass, 3, 'Correct number of lanes with updated class');
    });

    // run the tests.
    QUnit.start();
  }
);

