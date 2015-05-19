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

var NPG;
(function (NPG) {
  (function (QC) {
    
    /**
     * Object to keep configuration for resources.
     */
    var ProdConfiguration = (function() {
      function ProdConfiguration () {
        
      }
      
      ProdConfiguration.prototype.getRoot = function() {
        return '/static'; 
      };
      
      return ProdConfiguration;
    }) ();
    QC.ProdConfiguration = ProdConfiguration;
    
    /*
     * Controller for individual lanes GUI.
     */
    var LaneMQCControl = (function () {
      function LaneMQCControl(index, abstractConfiguration) {
        this.lane_control          = null;  // Container linked to this controller
        this.outcome               = null;  // Current outcome (Is updated when linked to an object in the view)
        this.index                 = index; // Index of control in the page.
        this.abstractConfiguration = abstractConfiguration;
        
        this.CONFIG_UPDATE_SERVICE      = "/mqc/update_outcome";
        this.CONFIG_ACCEPTED_PRELIMINAR = 'Accepted preliminary';
        this.CONFIG_REJECTED_PRELIMINAR = 'Rejected preliminary';
        this.CONFIG_ACCEPTED_FINAL      = 'Accepted final';
        this.CONFIG_REJECTED_FINAL      = 'Rejected final';
        this.UNDECIDED                  = 'Undecided'; //Initial outcome for widgets
      }
      
      LaneMQCControl.prototype.updateOutcome = function(outcome) {
        var id_run = this.lane_control.data('id_run'); 
        var position = this.lane_control.data('position');
        var control = this;
        if(outcome != control.outcome) {
          //Show progress icon
          control.lane_control.find('.lane_mqc_working').html("<img src='"
              + this.abstractConfiguration.getRoot()
              + "/images/waiting.gif' title='Processing request.'>");
          //AJAX call.
          $.post(control.CONFIG_UPDATE_SERVICE, { id_run: id_run, position : position, new_oc : outcome}, function(data){
            var response = data;
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
      LaneMQCControl.prototype.generateActiveControls = function() {
        var lane_control = this.lane_control;
        var self = this;
        this.lane_control.html("<img class='lane_mqc_control_accept' src='"
            + self.abstractConfiguration.getRoot()
            + "/images/tick.png' title='Accept'>" 
            + "<img class='lane_mqc_control_reject' src='"
            + self.abstractConfiguration.getRoot()
            + "/images/cross.png' title='Reject'>" 
            + "<div class='lane_mqc_working'></div>");    
        
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
      LaneMQCControl.prototype.saveAsFinalOutcome = function() {
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
      LaneMQCControl.prototype.setAcceptedBG = function() {
        this.lane_control.parent().css("background-color", "#B5DAFF");
      };
      
      LaneMQCControl.prototype.setRejectedBG = function () {
        this.lane_control.parent().css("background-color", "#FFDDDD");
      };
      
      LaneMQCControl.prototype.setAcceptedPre = function() {
        this.outcome = this.CONFIG_ACCEPTED_PRELIMINAR;    
        this.setAcceptedBG();
      };
      
      LaneMQCControl.prototype.setRejectedPre = function() {
        this.outcome = this.CONFIG_REJECTED_PRELIMINAR;
        this.setRejectedBG();
      };
      
      LaneMQCControl.prototype.setAcceptedFinal = function() {
        this.outcome = this.CONFIG_ACCEPTED_FINAL;
        this.setAcceptedBG();
      };
      
      LaneMQCControl.prototype.setRejectedFinal = function() {
        this.outcome = this.CONFIG_REJECTED_FINAL;
        this.setRejectedBG();
      };
      
      LaneMQCControl.prototype.replaceForLink = function() {
        var id_run = this.lane_control.data('id_run'); 
        var position = this.lane_control.data('position');
        this.lane_control.empty();
      };
      
      /* 
       * Links the individual object with an mqc controller so it can allow mqc of a lane.
       */
      LaneMQCControl.prototype.linkControl = function(lane_control) {
        lane_control.extra_handler = this;
        this.lane_control = lane_control;
        if ( typeof lane_control.data(this.UNDECIDED) === undefined) {
          //If it does not have initial outcome
          this.generateActiveControls();
        } else if (lane_control.data(this.UNDECIDED) === this.CONFIG_ACCEPTED_PRELIMINAR 
            || lane_control.data(this.UNDECIDED) === this.CONFIG_REJECTED_PRELIMINAR) {
          //If previous outcome is preliminar.
          this.generateActiveControls();
          switch (lane_control.data(this.UNDECIDED)){
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
      LaneMQCControl.prototype.loadBGFromInitial = function (lane_control) {
        lane_control.extra_handler = this;
        this.lane_control = lane_control;
        switch (lane_control.data(this.UNDECIDED)){
          case this.CONFIG_ACCEPTED_FINAL : this.setAcceptedFinal(); break;
          case this.CONFIG_REJECTED_FINAL : this.setRejectedFinal(); break;
        }
        lane_control.find('.lane_mqc_working').empty();
      };
      
      return LaneMQCControl;
    }) ();
    QC.LaneMQCControl = LaneMQCControl;

    /*
     * Object with rules for general things about QC and its
     * user interface.
     */
    var RunMQCControl = (function () {
      function RunMQCControl(abstractConfiguration) {
        this.abstractConfiguration = abstractConfiguration;
        this.mqc_run_data = null;
      }
      
      /*
       * Validates qc conditions and if everything is ready for qc it will call the 
       * target function passing parameters. If not qc ready will call mop function.
       */
      RunMQCControl.prototype.initQC = function (mqc_run_data, lanes, targetFunction, mopFunction) {
        var result = null;
        if(typeof(mqc_run_data) !== undefined && mqc_run_data != null) { //There is a data object
          this.mqc_run_data = mqc_run_data;
          if(this.isStateForMQC(mqc_run_data)) {
            result = targetFunction(mqc_run_data, this, lanes);
          } else {
            result = mopFunction();
          }
        } else {
          result = mopFunction();
        }
        return result;
      };
      
      /*
       * Checks all conditions related with the user in session and the
       * status of the run. Validates the user has privileges, has role,
       * the run is in correct status and the user in session is the
       * same as the user who took the QCing.
       */
      RunMQCControl.prototype.isStateForMQC = function (mqc_run_data) {
        if(typeof(mqc_run_data) === undefined 
            || mqc_run_data == null) {
          throw new Error("invalid arguments");
        }

        var result = typeof(mqc_run_data.taken_by) !== undefined  //Data object has all values needed.
          && typeof(mqc_run_data.current_user)!== undefined
          && typeof(mqc_run_data.has_manual_qc_role)!== undefined
          && typeof(mqc_run_data.current_status_description)!== undefined
          && mqc_run_data.taken_by == mqc_run_data.current_user /* Session & qc users are the same */
          && mqc_run_data.has_manual_qc_role == 1 /* Returns '' if not */
          && (mqc_run_data.current_status_description == 'qc in progress' //TODO move to class
            || mqc_run_data.current_status_description == 'qc on hold')
        return result;
      };
      
      RunMQCControl.prototype.showMQCOutcomes = function (mqc_run_data, lanes) {
        if(typeof(mqc_run_data) === undefined 
            || mqc_run_data == null 
            || typeof(lanes) === undefined 
            || lanes == null) {
          throw new Error("invalid arguments");
        }
        var self = this;

        var result = null;
        for(var i = 0; i < lanes.length; i++) {
          lanes[i].children('.lane_mqc_control').each(function(j, obj){
            $(obj).html("<div class='lane_mqc_working'><img src='" 
                + self.abstractConfiguration.getRoot() 
                + "/images/waiting.gif' title='Processing request.'></div>");
          });
        }
        
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
            var c = new NPG.QC.LaneMQCControl(i, self.abstractConfiguration);
            c.loadBGFromInitial(obj);
          }
        }
        return result;
      };
      
      /*
       * Update values in lanes with values from REST. Then link the lane
       * to a controller. The lane controller will update with widgets or
       * with proper background.
       */
      RunMQCControl.prototype.prepareLanes = function (mqc_run_data, lanes) {
        if(typeof(mqc_run_data) === undefined 
            || mqc_run_data == null 
            || typeof(lanes) === undefined 
            || lanes == null) {
          throw new Error("invalid arguments");
        }
        var result = null;
        var self = this;
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
            var c = new NPG.QC.LaneMQCControl(i, self.abstractConfiguration);
            c.linkControl(obj);
          }
        }
        return result;
      };
      
      /*
       * Validates if lanes' outcome returned from DWH and MQC match during manual QC.
       * Only checks in case there is an outcome in DWH, meaning there should be an 
       * outcome in manual QC.
       * 
       * It returns a value object with two properties:
       * 
       *  outcome: true/false for the result of the match. 
       *  position: null if matching, number of the first lane where there was a missmatch
       *   otherwise.
       */
      RunMQCControl.prototype.laneOutcomesMatch = function (lanesWithBG, mqc_run_data) {
        if(typeof(lanesWithBG) === undefined 
            || lanesWithBG == null 
            || typeof(mqc_run_data) === undefined
            || mqc_run_data == null) {
          throw "Error: invalid arguments";
        }
        var result = Object;
        result['outcome'] = true; //Outcome of the validation.
        result['position'] = null; //Which lane has the problem (if there is a problem).
        for(var i = 0; i < lanesWithBG.length && result; i++) {
          var cells = lanesWithBG[i].children('.lane_mqc_control');
          for(var j = 0; j < cells.length && result; j++) {
            var obj = $(cells[j]); //Wrap as an jQuery object.
            //Lane from row.
            var position = obj.data('position');
            //Filling previous outcomes
            if('qc_lane_status' in mqc_run_data) {
              if (position in mqc_run_data.qc_lane_status) {
                //From REST
                var currentStatusFromREST = mqc_run_data.qc_lane_status[position];
                //From DOM
                var currentStatusFromView = obj.data('initial');
                if(String(currentStatusFromREST) != String(currentStatusFromView) ) {
                  window.console && window.console.log('Warning: conflicting outcome in DWH/MQC, position ' 
                      + position + ' DWH:' + String(currentStatusFromView) 
                      + ' / MQC:' + String(currentStatusFromREST));
                }
              } else {
                result.outcome = false;
                result.position = position;
              }
            }
          }
        }
        return result;
      };

      return RunMQCControl;
    }) ();
    QC.RunMQCControl = RunMQCControl;

    /*
     * Object to deal with id_run parsing from text.
     */
    var RunTitleParser = (function () {
      function RunTitleParser() {
        this.reId = /^Results for run ([0-9]+) \(current run status:/;
      }
      
      /*
       * Parses the id_run from the title (or text) passed as param.
       * It looks for first integer using a regexp.
       * 
       * "^Results for run ([0-9]+) \(current run status:"
       */
      RunTitleParser.prototype.parseIdRun = function (text) {
        if(typeof(text) === undefined || text == null) {
          throw new Error("invalid arguments.");
        }
        var result = null;
        var match = this.reId.exec(text);
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
      
      return RunTitleParser;
    }) ();
    QC.RunTitleParser = RunTitleParser;
  }) (NPG.QC || (NPG.QC = {}));
  var QC = NPG.QC;
}) (NPG || (NPG = {}));




/*
* Check current state of the lanes. If current state is ready for QC, 
* get information from the page and prepare a VO object. Update the 
* lanes with GUI controls when necessary.
*/
function getQcState(mqc_run_data, runMQCControl, lanes) {
  //Show working icons
  for(var i = 0; i < lanes.length; i++) {
    lanes[i].children('.lane_mqc_control').each(function(j, obj){
      $(obj).html("<div class='lane_mqc_working'><img src='/static/images/waiting.gif' title='Processing request.'></div>");
    });
  }
  
  runMQCControl.prepareLanes(mqc_run_data, lanes);
}
