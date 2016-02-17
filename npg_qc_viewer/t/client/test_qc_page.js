/* globals $: false, define: false, QUnit: false */
"use strict";
require.config({
  baseUrl: '../../root/static',
  paths: {
    jquery: 'bower_components/jquery/dist/jquery',
  },
});

require(['scripts/qc_page'],
  function(qc_page) {

    QUnit.test("Parsing run lane", function (assert) {
      assert.throws(function() {qc_page._parseRunLane();}, /Error: Invalid arguments/, "Validates non-empty arguments");
      assert.throws(function() {qc_page._parseRunLane(null);}, /Error: Invalid arguments/, "Validates null argument");

      var run1 = qc_page._parseRunLane('NPG SeqQC v56.7: Results for run 16074 (run 16074 status: qc in progress, taken by aa11)');
      assert.ok(run1.isRunPage, 'Correctly identifies run page');

      var runlane1 = qc_page._parseRunLane('NPG SeqQC v56.7: Results (all) for runs 16074 lanes 2 (run 16074 status: qc on hold, taken by aa11)');
      assert.ok(!runlane1.isRunPage, 'Correctly identifies lane page');
    });

    QUnit.test("Parsing run status", function (assert) {
      assert.throws(function() {qc_page._parseRunStatus();}, /Error: Invalid arguments/, "Validates non-empty arguments");
      assert.throws(function() {qc_page._parseRunStatus(null);}, /Error: Invalid arguments/, "Validates null argument");

      var status1 = qc_page._parseRunStatus('');
      assert.equal(status1.runStatus, null, 'Can deal with empty string.');
      assert.equal(status1.takenBy, null, 'Can deal with empty string.');
      var status2 = qc_page._parseRunStatus('Bla bla bla');
      assert.equal(status2.runStatus, null, 'Can deal with random string');
      var status3 = qc_page._parseRunStatus('NPG SeqQC v56.7: Results for run number (run number status: qc in progress, taken by user)');
      assert.equal(status3.runStatus, null, 'Can deal with non valid run_id (lexical validation)');
      var status4 = qc_page._parseRunStatus('NPG SeqQC v56.7: Results for run (run status: qc in, taken by user)');
      assert.equal(status4.runStatus, null, 'Can deal with missing status (lexical validation)');
      var status5 = qc_page._parseRunStatus('NPG SeqQC v56.7: Results for run (run status: qc in progress, taken by )');
      assert.equal(status5.runStatus, null, 'Can deal with missing user (lexical validation)');
      assert.equal(status5.takenBy, null, 'Can deal with missing user (lexical validation)');


      var title1 = qc_page._parseRunStatus('NPG SeqQC v56.7: Results for run 16074 (run 16074 status: qc in progress, taken by aa11)');
      assert.equal(title1.takenBy, 'aa11', 'Correctly sets taken by to user');
      assert.equal(title1.runStatus, 'qc in progress', 'Correctly identifies the page as "qc in progress"');

      var title2 = qc_page._parseRunStatus('NPG SeqQC v56.7: Results (all) for runs 16074 lanes 2 (run 16074 status: qc on hold, taken by aa11)');
      assert.equal(title2.takenBy, 'aa11', 'Correctly sets lane page, run taken by to user');
      assert.equal(title2.runStatus, 'qc on hold', 'Correctly identifies lane page, run status as qc on hold');

      var title3 = qc_page._parseRunStatus("NPG SeqQC v56.7: Sample '1000ABCA1234567' (run 16074 status: qc in progress, taken by aa11)");
      assert.equal(title3.takenBy, 'aa11', 'Correctly sets sample page, run taken by to user');
      assert.equal(title3.runStatus, 'qc in progress', 'Correctly identifies sample page, run status as qc in progress');

      var title4 = qc_page._parseRunStatus('NPG SeqQC v56.7: Results (all) for runs 16074 lanes 1 2 (run 18731 status: qc in progress, taken by aa11)');
      assert.equal(title4.takenBy, 'aa11', 'Correctly sets run taken by to user for multiple lane page');
      assert.equal(title4.runStatus, 'qc in progress', 'Correctly identifies run status as qc in progress for multiple lane page');

      var title5 = qc_page._parseRunStatus('NPG SeqQC v56.7: Results (all) for runs 16074 16075 lanes 1');
      assert.equal(title5.runStatus, null, 'Can deal with multiple run page');
      assert.equal(title5.takenBy, null, 'Can deal with multiple run page');
      var title6 = qc_page._parseRunStatus('NPG SeqQC v56.7: Results (all) for runs 16074 16075 lanes 1 2');
      assert.equal(title6.runStatus, null, 'Can deal with multiple run, multiple lane page');
      assert.equal(title6.takenBy, null, 'Can deal with multiple run, multiple lane page');
    });

    QUnit.test("Parsing logged user", function (assert) {
      assert.throws(function() { qc_page._parseLoggedUser(); },
                               /Error: Invalid arguments/,
                               "Validates non-empty arguments");
      assert.throws(function() { qc_page._parseLoggedUser(null);},
                               /Error: Invalid arguments/,
                               "Validates null argument");
      var notLogged = ['Not logged in', '', ' ', 'Other description'];
      var logged    = 'Logged in as bb11';
      var loggedMQC = 'Logged in as aa11 (mqc)';

      for (var i = 0; i < notLogged.length; i++) {
        var result1 = qc_page._parseLoggedUser(notLogged[i]);
        assert.equal(result1.username, null, 'No logged user when not logged in, using: <' + notLogged[i] + '>');
        assert.equal(result1.role, null, 'No logged user role when not logged in, using: <' + notLogged[i] + '>');
      }

      var result2 = qc_page._parseLoggedUser(logged);
      assert.equal(result2.username, 'bb11', 'Username is properly parsed when logged in but not mqc');
      assert.equal(result2.role, null, 'Role is null when logged in but not mqc');

      var result3 = qc_page._parseLoggedUser(loggedMQC);
      assert.equal(result3.username, 'aa11', 'Username is properly parsed when logged in and mqc');
      assert.equal(result3.role, 'mqc', 'Role is mqc when logged in and mqc');
    });

    QUnit.test("Pages for manual QC", function (assert) {
      var originalTitle = document.title;

      $('#header h1 span.rfloat').text('Logged in as aa11 (mqc)');
      var titlesForQC = [
        'NPG SeqQC v0: Results for run 15000 (run 15000 status: qc in progress, taken by aa11)',
        'NPG SeqQC v0: Results for run 15000 (run 15000 status: qc on hold, taken by aa11)',
        'NPG SeqQC v0: Results (all) for runs 15000 lanes 1 (run 15000 status: qc in progress, taken by aa11)',
        'NPG SeqQC v0: Results (all) for runs 15000 lanes 1 (run 15000 status: qc on hold, taken by aa11)'
      ];

      for( var i = 0; i < titlesForQC.length; i++ ) {
        document.title = titlesForQC[i];
        var pageForMQC = qc_page.pageForMQC();
        assert.ok(pageForMQC.isPageForMQC, 'Page for manual QC');
      }

      document.title = originalTitle;
    });

    QUnit.test("Run / Lane page", function (assert) {
      var originalTitle = document.title;

      document.title = 'NPG SeqQC v0: Results for run 15000 (run 15000 status: qc in progress, taken by aa11)';
      var pageForMQC = qc_page.pageForMQC();
      assert.ok(pageForMQC.isRunPage, 'Page is correclty marked as run page');

      document.title = 'NPG SeqQC v0: Results (all) for runs 15000 lanes 1 (run 15000 status: qc on hold, taken by aa11)';
      pageForMQC = qc_page.pageForMQC();
      assert.ok(!pageForMQC.isRunPage, 'Page is correclty marked as not run page');

      $('#header h1 span.rfloat').text('Logged in as aa11');
      pageForMQC = qc_page.pageForMQC();
      assert.ok(!pageForMQC.isPageForMQC, 'Page is not for QC when user lacks mqc role');

      $('#header h1 span.rfloat').text('Not logged in');
      pageForMQC = qc_page.pageForMQC();
      assert.ok(!pageForMQC.isPageForMQC, 'Page is not for QC when no user logged in');

      document.title = originalTitle;
    });

    QUnit.start();
  }
);
