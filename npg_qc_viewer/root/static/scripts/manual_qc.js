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
 * Controller for individual lanes GUI.
 */
var LaneMQCControl = function (index) {
  this.lane_control = null;  // Container linked to this controller
  this.outcome      = null;  // Current outcome (Is updated when linked to an object in the view)
  this.index        = index; // Index of control in the page.
  
  this.CONFIG_UPDATE_SERVICE      = "http://sf2-farm-srv1.internal.sanger.ac.uk:35000/mqc/update_outcome";
  this.CONFIG_ACCEPTED_PRELIMINAR = 'Accepted preliminary';
  this.CONFIG_REJECTED_PRELIMINAR = 'Rejected preliminary';
  this.CONFIG_ACCEPTED_FINAL      = 'Accepted final';
  this.CONFIG_REJECTED_FINAL      = 'Rejected final';
  this.CONFIG_INITIAL             = 'initial';
  
  this.MESSAGE_ERROR_UPDATING = "Error while updating, please try again.";
  
  this.updateOutcome = function(outcome) {
    var id_run = this.lane_control.data('id_run'); 
    var position = this.lane_control.data('position');
    var control = this;
    if(outcome != control.outcome) {
      //Show progress icon
      control.lane_control.find('.lane_mqc_working').html("<img src='/static/images/waiting.gif' title='Processing request.'>");
      $.post(control.CONFIG_UPDATE_SERVICE, { id_run: id_run, position : position, new_oc : outcome})
      .done(function() {
        switch (outcome) {
          case control.CONFIG_ACCEPTED_PRELIMINAR : control.setAcceptedPre(); break; 
          case control.CONFIG_REJECTED_PRELIMINAR : control.setRejectedPre(); break;
          case control.CONFIG_ACCEPTED_FINAL : control.setAcceptedFinal(); break;
          case control.CONFIG_REJECTED_FINAL : control.setRejectedFinal(); break;
        }
        //Clear progress icon
        control.lane_control.find('.lane_mqc_working').html(position);
      })
      .fail(function() {
        alert(control.MESSAGE_ERROR_UPDATING);
        //Clear progress icon
        control.lane_control.find('.lane_mqc_working').html(position);
      });  
    } else {
      console.log("Noting to do!");
    }
  };
  
  /* 
   * Builds the gui controls necessary for the mqc operation and passes them to the view. 
   */ 
  this.generateActiveControls = function() {
    var lane_control = this.lane_control;
    lane_control.empty();
    //this.lane_control.html("<img class='lane_mqc_control_accept' src='tick.png' title='Accept'> <img class='lane_mqc_control_reject' src='cross.png' title='Reject'> <img class='lane_mqc_control_save' src='save.png' title='Save as final'> <div class='lane_mqc_working'></div>");
    this.lane_control.html("<img class='lane_mqc_control_accept' src='/static/images/tick.png' title='Accept'> <img class='lane_mqc_control_reject' src='/static/images/cross.png' title='Reject'> <div class='lane_mqc_working'></div>");    
    
    this.lane_control.find('.lane_mqc_control_accept').bind({click: function() {
      lane_control.extra_handler.updateOutcome(lane_control.extra_handler.CONFIG_ACCEPTED_FINAL);
    }});
    
    this.lane_control.find('.lane_mqc_control_reject').bind({click: function() {
      lane_control.extra_handler.updateOutcome(lane_control.extra_handler.CONFIG_REJECTED_FINAL);
    }});
    
    this.lane_control.find('.lane_mqc_control_save').bind({click: function() {
      lane_control.extra_handler.saveAsFinalOutcome();
    }});
  };
  
  /* 
   * Checks the current outcome associated with this controller. If it is not final it will make it final
   * will update the value in the model with an async call and update the view. 
   */
  this.saveAsFinalOutcome = function() {
    var control = this;
    
    if(this.outcome === this.CONFIG_ACCEPTED_PRELIMINAR) {
      this.updateOutcome(this.CONFIG_ACCEPTED_FINAL);
    }
    if(this.outcome === this.CONFIG_REJECTED_PRELIMINAR) {
      this.updateOutcome(this.CONFIG_REJECTED_FINAL);
    } 
  };
  
  /* 
   * Methods to deal with background colours. 
   */
  this.setAcceptedBG = function() {
    this.lane_control.css("background-color", "#B5DAFF");
  }
  
  this.setRejectedBG = function () {
    this.lane_control.css("background-color", "#FFDDDD");
  }
  
  this.setAcceptedPre = function() {
    this.outcome = this.CONFIG_ACCEPTED_PRELIMINAR;    
    this.setAcceptedBG();
  };
  
  this.setRejectedPre = function() {
    this.outcome = this.CONFIG_REJECTED_PRELIMINAR;
    this.setRejectedBG();
  };
  
  this.setAcceptedFinal = function() {
    this.replaceForLink();
    this.outcome = this.CONFIG_ACCEPTED_FINAL;
    this.updateOutcome(this.CONFIG_ACCEPTED_FINAL); //Remove if pre allowed
    this.setAcceptedBG();
  };
  
  this.setRejectedFinal = function() {
    this.replaceForLink();
    this.outcome = this.CONFIG_REJECTED_FINAL;
    this.updateOutcome(this.CONFIG_REJECTED_FINAL); //Remove if pre allowed
    this.setRejectedBG();
  };
  
  this.replaceForLink = function() {
    var id_run = this.lane_control.data('id_run'); 
    var position = this.lane_control.data('position');
    this.lane_control.empty();
    this.lane_control.html("<a href='#" + id_run + ":" + position + "'>" + position + "</a>");
  };
  
  /* 
   * Links the individual object with an mqc controller so it can allow mqc of a lane.
   */
  this.linkControl = function(lane_control) {
    lane_control.extra_handler = this;
    this.lane_control = lane_control;
    if ( typeof lane_control.data(this.CONFIG_INITIAL) == 'undefined') {
      //If it does not have initial outcome
      this.generateActiveControls();
    } else if (lane_control.data(this.CONFIG_INITIAL) === this.CONFIG_ACCEPTED_PRELIMINAR 
        || lane_control.data(this.CONFIG_INITIAL) === this.CONFIG_REJECTED_PRELIMINAR) {
      //If previous outcome is preliminar.
      this.generateActiveControls();
      switch (lane_control.data(this.CONFIG_INITIAL)){
        case this.CONFIG_ACCEPTED_PRELIMINAR : this.setAcceptedPre(); break;
        case this.CONFIG_REJECTED_PRELIMINAR : this.setRejectedPre(); break;
      }
    } else {
      switch (lane_control.data(this.CONFIG_INITIAL)){
        case this.CONFIG_ACCEPTED_FINAL : this.setAcceptedFinal(); break;
        case this.CONFIG_REJECTED_FINAL : this.setRejectedFinal(); break;
      }
    }
  };
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
  
  console.log("Flag :" + load_mqc_widgets);

  //To keep all individual lane controls.
  MQC.all_controls = []
  
  //Set up mqc controlers and link them to the individual lanes.
  $('.lane_mqc_control').each(function (i, obj) {
    obj = $(obj);
    var c = new LaneMQCControl(i);
    MQC.all_controls.push(c);
    c.linkControl(obj);
  });
}
