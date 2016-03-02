"use strict";
require.config({
  baseUrl: '../../root/static',
  paths: {
    jquery: 'bower_components/jquery/dist/jquery',
  },
});

require(['scripts/qcoutcomes/manual_qc', '../../t/client/test_fixtures'],
  function(NPG, fixtures) {

    var TestConfiguration = (function() {
      function TestConfiguration () {
      }

      TestConfiguration.prototype.getRoot = function() {
        return './';
      };

      return TestConfiguration;
    }) ();

    QUnit.test("loading", function ( assert ) {
      var a = fixtures.fixtures_dont_display;
    });

    QUnit.test("DOM linking", function( assert ) {
      var lane = $("#mqc_lane1");
      var control = new NPG.QC.LaneMQCControl(new TestConfiguration());
      assert.notEqual(control, undefined, "Control is an instance.");
      control.linkControl(lane);
      assert.notEqual(control.lane_control, undefined, "lane_control in Control is linked.");
      assert.equal(control.lane_control, lane, "Control and lane are correctly linked.");
      assert.equal(control.lane_control.outcome, undefined, "Outcome of lane is not defined.");
    });

    QUnit.test('Object initialisation', function() {
      var obj = null;
      ok(obj == null, "Variable is initially null.");
      obj = new NPG.QC.LaneMQCControl();
      ok(obj !== undefined, "Variable is now an instance.");
      obj = new NPG.QC.LaneMQCControl(new TestConfiguration());
      ok(obj !== undefined, "Variable is now a new instance called with parameter for constructor.");
      ok(obj.lane_control == null, "New object has null lane_control.");
      ok(obj.abstractConfiguration !== undefined, 'Object has a configuration');
      ok(obj.outcome == null, "New object has null outcome.");

      obj = null;
      ok(obj == null, "Variable back to null.");
      obj = new NPG.QC.LibraryMQCControl();
      ok(obj !== undefined, "Variable is now an instance.");
      obj = new NPG.QC.LibraryMQCControl(new TestConfiguration());
      ok(obj !== undefined, "Variable is now a new instance called with parameter for constructor.");
      ok(obj.lane_control == null, "New object has null lane_control.");
      ok(obj.abstractConfiguration !== undefined, 'Object has a configuration');
      ok(obj.outcome == null, "New object has null outcome.");
    });

    QUnit.test('Object instantiation for UI classes.', function() {
      var obj = null;

      obj = new NPG.QC.UI.MQCOutcomeRadio();
      ok(obj !== undefined, 'Variable is now an instance of MQCOutcomeRadio');
      obj = null;
      ok(obj == null);

      obj = new NPG.QC.UI.MQCLibraryOverallControls(new TestConfiguration());
      ok(obj !== undefined, 'Variable is now an instance of MQCLibraryOverallControls');
      obj = null;
      ok(obj == null);
    });
    
    QUnit.test

    // run the tests.
    QUnit.start();
  }
);


