test('Object initialisation', function() {
    var obj = null;
    ok(obj == undefined, "Variable is initially empty.");
    obj = new NPG.QC.LaneMQCControl();
    ok(obj !== undefined, "Variable is now an instance.");
    ok(obj.index == undefined, "Object has no initial index.");
    obj = new NPG.QC.LaneMQCControl(0);
    ok(obj !== undefined, "Variable is now a new instance called with parameters for constructor.");
    ok(obj.index !== undefined, "New object has an initial index.");
    ok(obj.lane_control == undefined, "New object has empty lane_control.");
    ok(obj.outcome == undefined, "New object has empty outcome.");
})

