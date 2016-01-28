"use strict";
require.config({
  baseUrl: '../../root/static',
  paths: {
    jquery: 'bower_components/jquery/dist/jquery',
  },
});

require(['scripts/manual_qc_outcomes',],
  function(mqc_outcomes) {
    // run the tests.
    QUnit.test('Simple', function (assert) {
      assert.equal(1, 1, 'Is ok');
    });

    QUnit.test('Parsing RPT keys', function (assert) {
      var rptKeys = mqc_outcomes.parseRptKeys('results_summary');
      var expected = ['18245:1', '18245:1:1', '18245:1:2'];
      assert.deepEqual(rptKeys, expected, 'Correct rpt keys');
    });

    QUnit.start();
  }
);

