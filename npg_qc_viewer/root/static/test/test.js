//Adjusting root for tests.
var TestConfiguration = (function() {
  function TestConfiguration () {
  }

  TestConfiguration.prototype.getRoot = function() {
    return 'test/images';
  };

  return TestConfiguration;
}) ();

test('Object initialisation', function() {
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

  obj = null;
  ok(obj == null, "Variable back to null.");
  obj = new NPG.QC.RunPageMQCControl();
  ok(obj !== undefined, 'variable is now an instance of RunPageMQCControl');
  obj = new NPG.QC.RunPageMQCControl(new TestConfiguration());
  ok(obj !== undefined, 'variable is now an instance of RunPageMQCControl');

  obj = null;
  ok(obj == null, "Variable back to null.");
  obj = new NPG.QC.LanePageMQCControl();
  ok(obj !== undefined, 'variable is now an instance of LanePageMQCControl');
  obj = new NPG.QC.LanePageMQCControl(new TestConfiguration());
  ok(obj !== undefined, 'variable is now an instance of LanePageMQCControl');

  obj = new NPG.QC.RunTitleParser();
  ok(obj !== undefined, 'variable is now an instance of RunTitleParser');
});

test('Object instantiation for UI classes.', function() {
  var obj = null;

  obj = new NPG.QC.UI.MQCOutcomeRadio();
  ok(obj !== undefined, 'Variable is now an instance of MQCOutcomeRadio');
  obj = null;
  ok(obj == null);

  obj = new NPG.QC.UI.MQCConflictDWHErrorMessage();
  ok(obj !== undefined, 'Variable is now an instance of MQCOutcomeMQCConflictDWHErrorMessage');
  obj = null;
  ok(obj == null);

  obj = new NPG.QC.UI.MQCLibraryOverallControls();
  ok(obj !== undefined, 'Variable is now an instance of MQCLibraryOverallControls');
  obj = null;
  ok(obj == null);

  obj = new NPG.QC.UI.MQCLibrary4LaneStats();
  ok(obj !== undefined, 'Variable is now an instance of MQCLibrary4LaneStats');
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

QUnit.test('Preparing table for download as csv', function (assert) {
  var helper = new NPG.QC.TableFormaterCSV();
  ok(helper !== undefined, 'Variable is now an instance of ProdConfiguration');

  var tableHtml = $('#results_summary')[0].outerHTML;

  var indexLibrary = tableHtml.indexOf('Library');
  assert.equal(indexLibrary, 105, 'Text contains Library');

  assert.equal(tableHtml.indexOf('<br>'), 112, 'Text has <br>');
  assert.equal(tableHtml.indexOf('|'), -1, 'Text does not have pipes');
  var withoutBreaks = helper.removeBreaks(tableHtml);
  //window.console.log(withoutBreaks);
  assert.equal(withoutBreaks.indexOf('<br>'), -1, 'No more <br>');
  assert.equal(withoutBreaks.indexOf('<br >'), -1, 'No more <br >');
  assert.equal(withoutBreaks.indexOf('<br />'), -1, 'No more <br />');
  assert.equal(withoutBreaks.indexOf('|'), 112, 'Replaced with pipe');
  
  var withFullHeaders = $(withoutBreaks);
  helper.fixHeaders(withFullHeaders);
  tableHtml = withFullHeaders[0].outerHTML;
  assert.equal(tableHtml.indexOf('<br>'), -1, 'No more <br>');
  assert.equal(tableHtml.indexOf('adapters,'), -1, 'Second header row is gone');
  assert.equal(tableHtml.indexOf('rowspan'), -1, 'No rowspans in title');
  
  helper.markForExport(withFullHeaders);
  assert.equal(withFullHeaders.data('tableexport-display'), 'always', 'Table marked for export');
});
