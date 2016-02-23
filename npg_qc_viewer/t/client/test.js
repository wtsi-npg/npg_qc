"use strict";
require.config({
  baseUrl: '../../root/static',
  paths: {
    jquery: 'bower_components/jquery/dist/jquery',
  },
});

require(['scripts/manual_qc'],
  function(NPG) {

    var TestConfiguration = (function() {
      function TestConfiguration () {
      }

      TestConfiguration.prototype.getRoot = function() {
        return './';
      };

      return TestConfiguration;
    }) ();

    QUnit.test("DOM linking", function( assert ) {
      var lane = $("#mqc_lane1");
      assert.notEqual(lane, undefined, "mqc_lane is an instance.");
      assert.equal(lane.data('id_run'), '2', "id_run is 2.");
      assert.equal(lane.data('position'), '3', "position is 3.");
      assert.equal(lane.data('initial'), undefined, "No initial value.");
      var control = new NPG.QC.LaneMQCControl(new TestConfiguration());
      assert.notEqual(control, undefined, "Control is an instance.");
      control.linkControl(lane);
      assert.notEqual(control.lane_control, undefined, "lane_control in Control is linked.");
      assert.equal(control.lane_control, lane, "Control and lane are correctly linked.");
      assert.equal(control.lane_control.outcome, undefined, "Outcome of lane is not defined.");
    });

    QUnit.test("DOM linking lane with previous status", function( assert ) {
      var lane = $("#mqc_lane2");
      assert.notEqual(lane, undefined, "mqc_lane is an instance.");
      assert.equal(lane.data('id_run'), '3', "id_run is 3.");
      assert.equal(lane.data('position'), '4', "position is 4.");
      assert.notEqual(lane.data('initial'), undefined, "Has initial value.");
      assert.equal(lane.data('initial'), 'Accepted final', "Initial value as expected.");
      var control = new NPG.QC.LaneMQCControl(new TestConfiguration());
      assert.notEqual(control, undefined, "Control is an instance.");
      control.linkControl(lane);
      assert.notEqual(control.lane_control, undefined, "lane_control in Control is linked.");
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

      obj = new NPG.QC.UI.MQCLibraryOverallControls();
      ok(obj !== undefined, 'Variable is now an instance of MQCLibraryOverallControls');
      obj = null;
      ok(obj == null);
    });

    QUnit.test('Error messaging formating', function (assert) {
      var obj = null;

      var FROM_EXCEPTION = 'Error: No LIMS data for this run/position. at /src/../lib/npg_qc_viewer/Controller.pm line 1000.';
      var EXPECTED_FE    = 'Error: No LIMS data for this run/position.';
      var FROM_GNR_TEXT  = 'A random error in the interface. And some more text. No numbers should be removed 14.';
      var EXPECTED_GT    = FROM_GNR_TEXT;

      obj = new NPG.QC.UI.MQCErrorMessage(FROM_EXCEPTION);
      assert.equal(obj.formatForDisplay(), EXPECTED_FE, 'Correctly parses from exception');
      obj = new NPG.QC.UI.MQCErrorMessage(FROM_GNR_TEXT);
      assert.equal(obj.formatForDisplay(), EXPECTED_GT, 'Correctly parses from general text');
    });

    // run the tests.
    QUnit.start();
  }
);


