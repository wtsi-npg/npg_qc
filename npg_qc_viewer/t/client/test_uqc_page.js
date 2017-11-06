/* globals $, requirejs, QUnit, document */

"use strict";
requirejs.config({
  baseUrl: '../../root/static',
  paths: {
    'qunit': 'bower_components/qunit/qunit/qunit',
    jquery:  'bower_components/jquery/dist/jquery'
  }
});

requirejs(['scripts/qcoutcomes/qc_page'],
  function(qc_page) {
    QUnit.config.autostart = false;


    QUnit.test("Parsing run status", function (assert) {

      var title = qc_page._parseRunStatus('NPG SeqQC v64.1: Results for run 24169 (run 24169 status: run archived)');
      assert.equal(title.takenBy, null, 'Correctly sets taken by to null user');
      assert.equal(title.runStatus, 'run archived', 'Correctly identifies the page as "run archived"');

      title = qc_page._parseRunStatus('NPG SeqQC v64.1: Results for run 24169 (run 24169 status: qc complete)');
      assert.equal(title.takenBy, null, 'Correctly sets taken by to null user');
      assert.equal(title.runStatus, 'qc complete', 'Correctly identifies the page as "qc complete"');

      
    });

    QUnit.test("Valid pages for UQC annotation", function (assert) {
      var originalTitle = document.title;

      var emptyStrings = [ '', ' ' ];
      var funct = function() { qc_page.pageForQC(); };
      for ( var i = 0; i < emptyStrings.length; i++ ) {
        document.title = emptyStrings[i];
        assert.throws( funct,
                       /Error: page title is expected but not available in page/,
                       "Throws error when page has empty title" );
      }
      document.title = originalTitle;
      for ( i = 0; i < emptyStrings.length; i++ ) {
        $('#header h1 span.rfloat').text(emptyStrings[i]);
        assert.throws( funct, 
                       /Error: authentication data is expected but not available in page/,
                       "Throws error when authentication info is empty" );
      }

      $('#header h1 span.rfloat').text('Logged in as aa11 (mqc)');
      var titlesForUQC = [
        'NPG SeqQC v0: Results for run 15000 (run 15000 status: qc complete)',
        'NPG SeqQC v0: Results for run 15000 (run 15000 status: run archived)',
        'NPG SeqQC v0: Results (all) for runs 15000 lanes 1 (run 15000 status: qc complete)',
        'NPG SeqQC v0: Results (all) for runs 15000 lanes 1 (run 15000 status: run archived)'
      ];

      for( i = 0; i < titlesForUQC.length; i++ ) {
        document.title = titlesForUQC[i];
        var pageForUQC = qc_page.pageForQC();
        assert.ok(pageForUQC.isPageForUQC, 'Page for utility QC');
      }

      var titlesNotForUQC = [
        "NPG SeqQC v0: Libraries: 'AA123456B'",
        "NPG SeqQC v0: Sample '1234ABCD1234567'",
        "NPG SeqQC v0: Pool AA123456B"
      ];

      for( i = 0; i < titlesNotForUQC.length; i++ ) {
        document.title = titlesNotForUQC[i];
        pageForUQC = qc_page.pageForQC();
        assert.ok(!pageForUQC.isPageForUQC, 'Non run pages are not for Utility QC');
      }

      titlesNotForUQC = [
        'NPG SeqQC v0: Results (all) for runs 16074 lanes 1 2 (run 16074 status: qc completed)',
        'NPG SeqQC v0: Results (all) for runs 16074 16075 lanes 1',
      ];
      for( i = 0; i < titlesNotForUQC.length; i++ ) {
        document.title = titlesNotForUQC[i];
        pageForUQC = qc_page.pageForQC();
        assert.ok(!pageForUQC.isPageForUQC, 'Pages with data for multiple runs/lanes are not for Utility QC');
      }

      document.title = 'NPG SeqQC v0: Results for run 15000 (run 15000 status: qc in progress, taken by aa11)';

      $('#header h1 span.rfloat').text('Logged in as aa11');
      pageForUQC = qc_page.pageForQC();
      assert.ok(!pageForUQC.isPageForUQC, 'Page is not for utility QC when user lacks reviewer role');

      $('#header h1 span.rfloat').text('Not logged in');
      pageForUQC = qc_page.pageForQC();
      assert.ok(!pageForUQC.isPageForUQC, 'Page is not for utility QC when no user is logged in');

      document.title = originalTitle;
    });

    QUnit.test("Run / Lane page", function (assert) {
      var originalTitle = document.title;

      document.title = 'NPG SeqQC v0: Results for run 15000 (run 15000 status: qc complete)';
      var pageForUQC = qc_page.pageForQC();
      assert.ok(pageForUQC.isRunPage, 'Page is correclty marked as run page');

      document.title = 'NPG SeqQC v0: Results (all) for runs 15000 lanes 1 (run 15000 status: run archived)';
      pageForUQC = qc_page.pageForQC();
      assert.ok(!pageForUQC.isRunPage, 'Page is correclty marked as not run page');

      document.title = "NPG SeqQC v0: Libraries: 'AA123456B'";
      pageForUQC = qc_page.pageForQC();
      assert.ok(!pageForUQC.isRunPage, 'Page is correclty marked as not run page');

      document.title = originalTitle;
    });

    QUnit.start();
  }
);
