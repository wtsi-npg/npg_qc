"use strict";
require.config({
  baseUrl: '../../root/static',
  paths: {
    jquery: 'bower_components/jquery/dist/jquery',
  },
});

require(['scripts/qc_page'],
  function(qc_page) {

    QUnit.test("Parsing title", function (assert) {
      assert.ok(qc_page);
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
        assert.equal(result1.loggedUser, null, 'No logged user when not logged in, using: <' + notLogged[i] + '>');
        assert.equal(result1.loggedUserRole, null, 'No logged user role when not logged in, using: <' + notLogged[i] + '>');
      }

      var result2 = qc_page._parseLoggedUser(logged);
      assert.equal(result2.loggedUser, 'bb11', 'Username is properly parsed when logged in but not mqc');
      assert.equal(result2.loggedUserRole, null, 'Role is null when logged in but not mqc');

      var result3 = qc_page._parseLoggedUser(loggedMQC);
      assert.equal(result3.loggedUser, 'aa11', 'Username is properly parsed when logged in and mqc');
      assert.equal(result3.loggedUserRole, 'mqc', 'Role is mqc when logged in and mqc');
    });

    QUnit.test("QC page", function (assert) {
      assert.ok(qc_page);
    });

    QUnit.start();
  }
);
