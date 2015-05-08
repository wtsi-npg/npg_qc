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
*
************************************************************************************/

/*
 * Controller for individual lanes GUI.
 */
var LaneMQCControl = function (index) {
  this.lane_control = null;  // Container linked to this controller
  this.outcome      = null;  // Current outcome (Is updated when linked to an object in the view)
  this.index        = index; // Index of control in the page.
  
  this.CONFIG_UPDATE_SERVICE      = "/mqc/update_outcome";
  this.CONFIG_ACCEPTED_PRELIMINAR = 'Accepted preliminary';
  this.CONFIG_REJECTED_PRELIMINAR = 'Rejected preliminary';
  this.CONFIG_ACCEPTED_FINAL      = 'Accepted final';
  this.CONFIG_REJECTED_FINAL      = 'Rejected final';
  this.CONFIG_INITIAL             = 'initial';
  
  this.getRoot = function() {
    return '/static';
  };
  
  this.updateOutcome = function(outcome) {
    var id_run = this.lane_control.data('id_run'); 
    var position = this.lane_control.data('position');
    var control = this;
    if(outcome != control.outcome) {
      //Show progress icon
      control.lane_control.find('.lane_mqc_working').html("<img src='"+control.getRoot()+"/images/waiting.gif' title='Processing request.'>");
      //AJAX call.
      $.post(control.CONFIG_UPDATE_SERVICE, { id_run: id_run, position : position, new_oc : outcome}, function(data){
        var response = data;
        window.console && console.log(response.message);
        control.lane_control.find('.lane_mqc_working').empty();
      }, "json")
      .done(function() {
        switch (outcome) {
          case control.CONFIG_ACCEPTED_PRELIMINAR : control.setAcceptedPre(); break; 
          case control.CONFIG_REJECTED_PRELIMINAR : control.setRejectedPre(); break;
          case control.CONFIG_ACCEPTED_FINAL : control.setAcceptedFinal(); break;
          case control.CONFIG_REJECTED_FINAL : control.setRejectedFinal(); break;
        }
        //Clear progress icon
        control.lane_control.empty();
      })
      .fail(function(data) {
        window.console && console.log(data.responseJSON.message);
        jQuery("#ajax_status").append("<li class='failed_mqc'>" + data.responseJSON.message + "</li>");
        //Clear progress icon
        control.lane_control.find('.lane_mqc_working').empty();
      });  
    } else {
      window.console && console.log("Noting to do.");
    }
  };
  
  /* 
   * Builds the gui controls necessary for the mqc operation and passes them to the view. 
   */ 
  this.generateActiveControls = function() {
    var lane_control = this.lane_control;
    this.lane_control.html("<img class='lane_mqc_control_accept' src='"+this.getRoot()+"/images/tick.png' title='Accept'>" + 
        "<img class='lane_mqc_control_reject' src='"+this.getRoot()+"/images/cross.png' title='Reject'>" + 
        "<div class='lane_mqc_working'></div>");    
    
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
    this.lane_control.parent().css("background-color", "#B5DAFF");
  }
  
  this.setRejectedBG = function () {
    this.lane_control.parent().css("background-color", "#FFDDDD");
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
    this.outcome = this.CONFIG_ACCEPTED_FINAL;
    this.setAcceptedBG();
  };
  
  this.setRejectedFinal = function() {
    this.outcome = this.CONFIG_REJECTED_FINAL;
    this.setRejectedBG();
  };
  
  this.replaceForLink = function() {
    var id_run = this.lane_control.data('id_run'); 
    var position = this.lane_control.data('position');
    this.lane_control.empty();
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
      this.loadBGFromInitial(lane_control);
    }
  };
  
  /*
   * Changes the background of the parent element depending on the initial outcome
   * of the lane.
   */
  this.loadBGFromInitial = function (lane_control) {
    lane_control.extra_handler = this;
    this.lane_control = lane_control;
    switch (lane_control.data(this.CONFIG_INITIAL)){
      case this.CONFIG_ACCEPTED_FINAL : this.setAcceptedFinal(); break;
      case this.CONFIG_REJECTED_FINAL : this.setRejectedFinal(); break;
    }
    lane_control.find('.lane_mqc_working').empty();
  };
}

var NPG = NPG || {};
NPG.QC = NPG.QC || {};

var RunMQCControl = (function () {
  function RunMQCControl(run_id) {
    this.run_id = run_id;
    this.mqc_run_data = null;
  }
  
  /*
   * Validates qc conditions and if everything is ready for qc it will call the 
   * target function passing parameters. If not qc ready will call mop function.
   */
  RunMQCControl.prototype.initQC = function (mqc_run_data, lanes, targetFunction, mopFunction) {
    var result = null;
    var control = this;
    if(typeof(mqc_run_data) != undefined && mqc_run_data != null) { //There is a data object
      this.mqc_run_data = mqc_run_data;
      if(typeof(mqc_run_data.taken_by) != undefined  //Data object has all values needed.
          && typeof(mqc_run_data.current_user)!= undefined
          && typeof(mqc_run_data.has_manual_qc_role)!= undefined
          && typeof(mqc_run_data.current_status_description)!= undefined) {
        if(mqc_run_data.taken_by == mqc_run_data.current_user /* Session & qc users are the same */
            && mqc_run_data.has_manual_qc_role == 1 /* Returns '' if not */
            && (mqc_run_data.current_status_description == 'qc in progress' //TODO move to class
              || mqc_run_data.current_status_description == 'qc on hold')) { //TODO move to class
          result = targetFunction(mqc_run_data, control, lanes);
        } else {
          result = mopFunction();
        }
      } else {
        result = mopFunction();
      }
    } else {
      result = mopFunction();
    }
    return result;
  };
  
  RunMQCControl.prototype.showMQCOutcomes = function (mqc_run_data, lanes) {
    var result = null;
    window.console && window.console.log("Here!");
    for(var i = 0; i < lanes.length; i++) {
      lanes[i].children('.lane_mqc_control').each(function(j, obj){
        $(obj).html("<div class='lane_mqc_working'><img src='/static/images/waiting.gif' title='Processing request.'></div>");
      });
    }
    
    //Required to show error messages from the mqc process.
    $("#results_summary").before('<ul id="ajax_status"></ul>'); 
    
    for(var i = 0; i < lanes.length; i++) {
      var cells = lanes[i].children('.lane_mqc_control');
      for(j = 0; j < cells.length; j++) {
        obj = $(cells[j]); //Wrap as an jQuery object.
        //Lane from row.
        var position = obj.data('position');
        //Filling previous outcomes
        if('qc_lane_status' in mqc_run_data && position in mqc_run_data.qc_lane_status) {
          //From REST
          current_status = mqc_run_data.qc_lane_status[position];
          //To html element, LaneControl will render.
          obj.data('initial', current_status);
        }
        //Set up mqc controlers and link them to the individual lanes.
        var c = new LaneMQCControl(i);
        c.loadBGFromInitial(obj);
      }
    }
    return result;
  };
  
  RunMQCControl.prototype.prepareLanes = function (mqc_run_data, lanes) {
    var result = null;
    for(var i = 0; i < lanes.length; i++) {
      var cells = lanes[i].children('.lane_mqc_control');
      for(j = 0; j < cells.length; j++) {
        obj = $(cells[j]); //Wrap as an jQuery object.
        //Lane from row.
        var position = obj.data('position');
        //Filling previous outcomes
        if('qc_lane_status' in mqc_run_data && position in mqc_run_data.qc_lane_status) {
          //From REST
          current_status = mqc_run_data.qc_lane_status[position];
          //To html element, LaneControl will render.
          obj.data('initial', current_status);
        }
        //Set up mqc controlers and link them to the individual lanes.
        var c = new LaneMQCControl(i);
        c.linkControl(obj);
      }
    }
    return result;
  };
  
  return RunMQCControl;
}) ();
NPG.QC.RunMQCControl = RunMQCControl;

var RunTitleParser = (function () {
  function RunTitleParser() {
    this.reId = /^Results for run ([0-9]+) \(current run status:/;
  }
  
  RunTitleParser.prototype.parseIdRun = function (element) {
    var match = this.reId.exec(element);
    var result = null;
    //There is a result from parsing
    if (match != null) {
      //The result of parse looks like a parse 
      // and has correct number of elements
      if(match.constructor === Array && match.length >= 2) {
        result = match[1];
      }
    }
    return result;
  };
  
  RunTitleParser.prototype.parse = function (element) {
    var match = this.reIdFull.exec(element);
    var result = null;
    //There is a result from parsing
    if (match != null) {
      //The result of parse looks like a parse 
      // and has correct number of elements
      if(match.constructor === Array && match.length >= 2) {
        result = match[1];
      }
    }
    return result;
  };
  
  /*
   * Validates if lanes' outcome returned from DWH and MQC match during manual QC.
   * Only checks in case there is an outcome in DWH, meaning there should be an 
   * outcome in manual QC.
   */
  RunTitleParser.prototype.laneOutcomesMatch = function (lanesWithBG, lanesWithoutBG, mqc_run_data) {
    //TOOD validate lane outcomes match
    result = true;
    
    return result;
  };
  
  return RunTitleParser;
}) ();
NPG.QC.RunTitleParser = RunTitleParser;

/*
* Check current state of the lanes. If current state is ready for QC, 
* get information from the page and prepare a VO object. Update the 
* lanes with GUI controls when necessary.
*/
function getQcState(mqc_run_data, runMQCControl, lanes) {
  //Preload images for working icon
  $('<img/>')[0].src = "/static/images/waiting.gif";

  //Show working icons
  for(var i = 0; i < lanes.length; i++) {
    lanes[i].children('.lane_mqc_control').each(function(j, obj){
      $(obj).html("<div class='lane_mqc_working'><img src='/static/images/waiting.gif' title='Processing request.'></div>");
    });
  }
  
  //Preload rest of icons
  $('<img/>')[0].src = "/static/images/tick.png";
  $('<img/>')[0].src = "/static/images/cross.png";
  
  //Required to show error messages from the mqc process.
  $("#results_summary").before('<ul id="ajax_status"></ul>'); 
  
  //TODO Move to method in controller and call method.
  runMQCControl.prepareLanes(mqc_run_data, lanes);
}
