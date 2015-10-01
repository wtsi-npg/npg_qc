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
  ok(obj.outcome == null, "New object has null outcome.");

  obj = new NPG.QC.RunPageMQCControl();
  ok(obj !== undefined, 'variable is now an instance of RunPageMQCControl');
  obj = new NPG.QC.RunPageMQCControl(new TestConfiguration());
  ok(obj !== undefined, 'variable is now an instance of RunPageMQCControl');

  obj = new NPG.QC.RunTitleParser();
  ok(obj !== undefined, 'variable is now an instance of RunTitleParser');
});

