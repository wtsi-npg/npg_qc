  $(document).ready(function(){

module("npg_common.js");

test("st service URIs", function() {
  expect(1);
  lims_api_url = "http://psd.dev.sanger.ac.uk:6610";
  equals( service_uri(), lims_api_url, "psd uri, no arg" );
});

test("base uri", function() {
  expect(1);
  equals(base_uri(), location.protocol + "//" + location.host, "base uri is correct");
});

module("manual_qc.js: updating library names from live service");

test("run updateLibs function non-recursively", function() {

  expect(11);
  var no_recurse = 1;
  var lib_names = new Array();
  var err;
  try {
    updateLibs(lib_names, 2);
  } catch (e) {err = e;}
  equals(err, "MQC_ERROR: lib names array empty", "error when lib names array is empty");

  lib_names[0] = "dodo";
  try {
    updateLibs(lib_names, 2);
  } catch (e) {err = e;}
  equals(err, "MQC_ERROR: invalid position", "error for invalid position value");

  try {
    updateLibs(lib_names, 0);
  } catch (e) {err = e;}
  equals(err, "MQC_ERROR: invalid position", "error for invalid position value");

  lib_names[2] = "dada";
  try {
    updateLibs(lib_names, 2);
  } catch (e) {err = e;}
  equals(err, "MQC_ERROR: undefined lib name for position 2", "error for invalid position value");    
  
  lib_names[1] = "dodo";
  ok( updateLibs(lib_names, 2, no_recurse) , "updateLibNames runs ok for existing element" );
  ok(!updateLibs(lib_names, 3, no_recurse), "runs ok for non-existing element" );

  var lib_span = jQuery("#test_lib2_name");
  equals(lib_span[0].firstChild.nodeValue, lib_names[1], 'lib2 name changed');
  equals(lib_span[0].parentNode.getAttribute("href"), "http://dodo.com?name=dodo", 'lib2 ref changed');

  lib_names[1] = "moi dodo";
  ok( updateLibs(lib_names, 2, no_recurse) , "updateLibNames runs ok lib name with a space" );
  equals(lib_span[0].firstChild.nodeValue, lib_names[1], 'lib2 name changed');
  equals(lib_span[0].parentNode.getAttribute("href"), "http://dodo.com?name=moi%20dodo", 'lib2 ref changed and is correctly encoded');
});

test("run updateLibs function recursively", function() {

  expect(5);
  var no_recurse = 0;
  var lib_names = new Array("dodo", "dodo", "dada");

  ok( updateLibs(lib_names, 2, no_recurse) , "runs ok with a recursive option" );

  var lib_span = jQuery("#test_lib2_name");
  equals(lib_span[0].firstChild.nodeValue, lib_names[1], 'lib2 name changed');
  equals(lib_span[0].parentNode.getAttribute("href"), "http://dodo.com?name=dodo", 'lib2 ref changed');

  lib_span = jQuery("#test_lib1_name");
  equals(lib_span[0].firstChild.nodeValue, lib_names[1], 'lib1 name changed');
  equals(lib_span[0].parentNode.getAttribute("href"), "http://dodo.com?name=dodo", 'lib1 ref changed');
});

test("run updateLibs function recursively", function() {

  expect(5);
  var no_recurse = 0;
  var lib_names = new Array("dudu", "dodo", "dada");
  var lib_span = jQuery("#test_lib1_name");
  var lib1_name = lib_span[0].firstChild.nodeValue;

  ok( updateLibs(lib_names, 2, no_recurse) , "runs ok with a recursive option" );

  lib_span = jQuery("#test_lib2_name");
  equals(lib_span[0].firstChild.nodeValue, lib_names[1], 'lib2 name changed');
  equals(lib_span[0].parentNode.getAttribute("href"), "http://dodo.com?name=dodo", 'lib1 ref changed');

  lib_span = jQuery("#test_lib1_name");
  equals(lib_span[0].firstChild.nodeValue, lib1_name, 'lib1 name not changed');
  equals(lib_span[0].parentNode.getAttribute("href"), "http://dodo.com?name=some_ref", 'lib1 ref changed');
});

module("manual_qc.js: misc functions");
test("getting opposite qc status", function() {
  expect(3);
  try {
    getOppositeStatus("some_status");
  } catch (e) {err = e;}
  equals(err, "MQC_ERROR: invalid status some_status", "error for invalid status value");
  equals(getOppositeStatus("failed"), "passed", "passed is opp to failed");
  equals(getOppositeStatus("passed"), "failed", "failed is opp to passed");
});

  });
