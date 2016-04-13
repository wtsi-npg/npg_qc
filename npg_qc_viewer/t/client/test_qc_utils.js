"use strict";
require.config({
  baseUrl: '../../root/static',
  paths: {
    jquery: 'bower_components/jquery/dist/jquery',
  },
});

require(['scripts/qcoutcomes/qc_utils'],
  function(qc_utils) {

    QUnit.test('RPT key from id', function (assert) {
      assert.throws(
        function () { qc_utils.rptKeyFromId() },
        /Invalid arguments/,
        'Validates undefined id'
      );

      var validIds = [ 'rpt_key:10000:1:2', 'rpt_key:10000:1' ];
      var validRptKeys = ['10000:1:2', '10000:1'];
      for( var i = 0; i < validIds.length; i++ ) {
        assert.equal(qc_utils.rptKeyFromId(validIds[i]), validRptKeys[i],
                     'Valid RPT key from id ' + validIds[i] + ' -> ' + validRptKeys[i]);
      }

      var invalidIds = [ 'prefix:10000:2', '10000:2', '10000:2:1' ];
      for( var i = 0; i < invalidIds.length; i++ ) {
        assert.throws(
          function () { qc_utils.rptKeyFromId(invalidIds[i]) },
          /Id does not match the expected format/,
          'Validates unexpected format for id'
        );
      }
    });
    // run the tests.
    QUnit.start();
  }
);
