/*
* Author:        Marina Gourtovaia
*
* Copyright (C) 2014 Genome Research Ltd.
*
* This file is part of NPG software.
*
* NPG is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

/************************************************************************************
*
* Interface for manual QC.
* Dependencies: jQuery library
*               npg_common.js
*
************************************************************************************/

/*
* Global variables
*/
var st_uri = service_uri();
var base = "../..";
var ajax_base = base + "/ajaxproxy?url=";
var lib_ids;


function getOppositeStatus(status) {
  if (status != "failed" && status != "passed") {
    throw "MQC_ERROR: invalid status " + status;
  }
  return status == "failed" ? "passed" : "failed";
}


/*
* Extract asset qc state from an XML document
*/
function extractAssetQcState(doc, asset_id) {

  var qcEl = doc.getElementsByTagName("qc_state").item(0);
  var qc_value = "";
  if (qcEl) {
    var qcElText = qcEl.firstChild;
    if (qcElText) {
      qc_value = qcElText.nodeValue;
    }
  } else {
    throw "MQC_ERROR: qc_state element is not found for asset " + asset_id;
  }
  return qc_value;
}


/*
* Log new manual qc status
*/
function logMqcStatus (asset_id, qc_type, status, position) {

  jQuery.ajax({
     type: "POST",
     data: {'lims_object_id'   : asset_id, 
            'lims_object_type' : qc_type, 
            'status'   : status, 
            'referer'  : decodeURI(location.href),
            'position' : position,
            'batch_id' : batch_id
           },
     url: base + "/mqc/log",
     error: function() {
      var target = "Batch: " + batch_id + ", lane " + position + ",  asset " + asset_id;
      var msg = "Error storing manual_qc result and updating status: " + status + " for " + target +  ".";
      jQuery("#ajax_status").append("<li>" + msg + "</li>");
      //jQuery("#mqc_lane_" + position).empty();
     }    
  });
}


/*
* Set the lib names to the values received from the live service
*/
function updateLibs(lib_names, position, no_recurse) {

  var alength = lib_names.length;
  if (alength < 1) {
    throw "MQC_ERROR: lib names array empty";
  }
  if (position < 1 || position > alength) {
    throw "MQC_ERROR: invalid position";
  }
  var new_lib_name = lib_names[position - 1];
  if (!new_lib_name) {
    throw "MQC_ERROR: undefined lib name for position " + position;
  }
  var div = jQuery("#mqc_lib_" + position);
  if (div) {
    var lib_name_el_span = div.parent().find(".lib");
    if (lib_name_el_span) {
      lib_name_el_span = lib_name_el_span[0];
    }
    if (lib_name_el_span) {
      var lib_name_el = lib_name_el_span.firstChild;
      if (lib_name_el) {
        lib_name_el.nodeValue = new_lib_name;
        var anchor_el = lib_name_el_span.parentNode;
        var old_ref = anchor_el.getAttribute("href");
        if (old_ref) {
	  var i = old_ref.lastIndexOf("=");
	  anchor_el.setAttribute("href", old_ref.substr(0, i+1) + encodeURIComponent(new_lib_name));
	}
        
        if (!no_recurse) {
          var recurse = 1;
          for (var j = 0; j < alength; j++) {
            var name = lib_names[j];
            if (name && position != j+1 && new_lib_name == name) {
	      updateLibs(lib_names, j+1, recurse);
            }
          }
        }
        return 1;
      }
    }
  }
  return 0;
}


/*
* Draw widgets and update visually for qc status
*/
function updateMqcWidget(qc_type, position, qc_state, asset_id, repeate) {

  var div_filter = "mqc_" + qc_type + '_' + position;
  var div = jQuery("#" + div_filter);

  if (div) {
    div.empty();

    var args = [position, "'pass'", asset_id, "'"+qc_type+"'"];
    if (!qc_state || qc_state == "pending") {
      div.append('<a href="javascript:void(0)" onclick="onMqcButtonClick(' + args.join(",") + ');"><img id="mqc_' + qc_type + '_pass_' + position + '" src="/static/images/tick.png" class="button button_pass" /></a>');
      args[1] = "'fail'";
      div.append('<a href="javascript:void(0)" onclick="onMqcButtonClick(' + args.join(",") + ');"><img id="mqc_' + qc_type + '_fail_' + position + '" src="/static/images/cross.png" class="button button_fail" /></a>');

    } 

    var class_names = qc_type;
    if (qc_state == "failed" || qc_state == "passed") {
      class_names = qc_state + " " + class_names;
    }
    div.parent().attr("class", class_names);
  }
}


/*
* Get qc state of an asset and produce an appropriate visual feedback
*/
function getAssetQcState(repeate, position, asset_id, qc_type, doc) {

  if (doc && jQuery.isXMLDoc(doc)) {
    updateMqcWidget(qc_type, position, extractAssetQcState(doc, asset_id), asset_id);
  } else {
    var asset_url = ajax_base + st_uri + "/assets/" + asset_id + ".xml";
    var asset_request = jQuery.ajax({
      url: asset_url,
      success: function() {
        var qcEl = asset_request.responseXML.getElementsByTagName("qc_state").item(0);
        if (qcEl) {
          var qc_value = "";
	  var qcElText = qcEl.firstChild;
	  if (qcElText) {
            qc_value = qcElText.nodeValue;
          }
          updateMqcWidget(qc_type, position, qc_value, asset_id, repeate);
        } else {
          throw "MQC_ERROR: qc_state element is not found for asset " + asset_id;
        } 
      }
    });
  }
}


/*
* Get request xml and from it lane asset id and its state
*/
function getRequest(request_id, position) {

  var request_url = ajax_base + st_uri + "/requests/" + request_id + ".xml";
  var requestRequest = jQuery.ajax({
    url: request_url,
    success: function() {
      var reqTagIdEl = requestRequest.responseXML.getElementsByTagName("target_asset_id").item(0);
      if (reqTagIdEl) {
	var reqTagIdElText = reqTagIdEl.firstChild;
	var lane_asset_id = "";
	if (reqTagIdElText) {
	  lane_asset_id = reqTagIdElText.nodeValue;
	}
	if(lane_asset_id) {
	  getAssetQcState(0, position, lane_asset_id, "lane");
	} else {
	  throw "MQC_ERROR: target_asset_id not defined for request " + request_id;
	}
      } else {
	throw "MQC_ERROR: target_asset_id element not found for request " + request_id;
      }
    },
    error: function() {
      jQuery("#ajax_status").append("<li>Failed to get " + request_url + "for lane " + position + "</li>");
      jQuery("#mqc_lane_" + position).empty();
    }
  });
}


/*
* Callback for a manual qc button click
*/
function onMqcButtonClick(position, change_to, asset_id, qc_type) {

  var div_filter       = "mqc_" + qc_type + "_" + position;
  var div = jQuery("#" + div_filter);
  div.empty();
  div.append('<img src="/static/images/waiting.gif" />');

  var event_url = ajax_base + st_uri + "/npg_actions/assets/" + asset_id + "/" + change_to + "_qc_state";
  var xml_data = '<?xml version="1.0" encoding="UTF-8"?><qc_information><message>Asset ' + asset_id + " " + change_to + "ed manual qc</message></qc_information>";

  var request = jQuery.ajax({
    type: "POST",
    contentType: "text/xml",
    processData: false,
    data: xml_data,
    url: event_url,
    beforeSend: function(xhr) {
      xhr.setRequestHeader("Accept", "application/xml");
      xhr.setRequestHeader("Content-Type", "application/xml");
      xhr.setRequestHeader("Content-Length", xml_data.length);
    },
    success: function() {
      var doc = request.responseXML;
      var root_name = doc.documentElement.tagName;
      var repeate = 0;

      if (root_name == "asset") {
        logMqcStatus(asset_id, qc_type, change_to, position);
        getAssetQcState(repeate, position, asset_id, qc_type, doc);
      } else {
        jQuery("#ajax_status").text("Some Sequencescape error when sending manual qc status");
        updateMqcWidget(qc_type, position, getOppositeStatus(change_to), asset_id);
      }
    },
    error: function() {
      var target = "batch " + batch_id + ", lane " + position + ",  asset " + asset_id;
      var msg = "Error reporting " + change_to + " for " + target +  ".";
      jQuery("#ajax_status").append("<li>" + msg + " <a href='mailto:seq-help@sanger.ac.uk?subject=Manual QC reporting error: " + target + "&body=" + msg + "'>Mail USG</a></li>");
      jQuery("#mqc_lane_" + position).empty();
    }    
  });
}


/*
* Get current QC state of lanes and libraries for all position via ajax calls
*/
function getQcState() {
  
  var divs = jQuery(".mqc");
  divs.empty();
  divs.append('<img src="/static/images/waiting.gif" />');

  var batch_url = ajax_base + st_uri + "/batches/" + batch_id + ".xml";

  lib_ids = [10];
  var lib_names = [10];

  var request = jQuery.ajax({
    url: batch_url,
    success: function () {

      jQuery(request.responseXML).find("lane").each(function() {

        var position = jQuery(this).attr('position');

        var libEl = jQuery(this).find("library").get(0);
        if (!libEl) {
          libEl = jQuery(this).find("pool").get(0); 
        }
        
        if (libEl) {
          lib_ids[position-1] = jQuery(libEl).attr('id');
          lib_names[position-1] = jQuery(libEl).attr('name');
          var request_id  = jQuery(libEl).attr('request_id');
          if (request_id) {
            getRequest(request_id, position);
          }
        } else {
            var div = jQuery("#mqc_lane_" + position);
            if (div) {
              div.empty();
            }
	}
      });

      var alength = lib_ids.length;
      for (var i = 0; i < alength; i++) {
	var lib_asset_id = lib_ids[i];
        if (lib_asset_id) {
	  var repeate = 0;
          for (var j = 0; j < i; j++) {
	    if (lib_ids[j] && lib_ids[j] == lib_asset_id) {
	      repeate = 1;
              break;
	    }
	  }
          if (!repeate) {
	    var pos = i + 1;
	    updateLibs(lib_names, pos);
	  }
	}
      }
    },
    error: function () {
      jQuery("#ajax_status").append("<li>Failed to get " + batch_url + "</li>");
      jQuery(".mqc").empty();
    }
  });
}
