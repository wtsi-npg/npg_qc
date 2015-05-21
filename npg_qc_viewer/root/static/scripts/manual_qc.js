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

/*
*
* Interface for manual QC.
* Dependencies: jQuery library
*
*/

var NPG;
/** 
 * @module NPG
 */ 
(function (NPG) {
  /**
   * @module NPG/QC
   */
  (function (QC) { 
    var ProdConfiguration = (function() {
      /**
       * Object to keep configuration for resources.
       * @memberof module:NPG/QC
       * @constructor
       * @author jmtc
       */
      function ProdConfiguration () {}
      
      /**
       * Returns the path for the resourses so it can be used by
       * other objects in the module.
       * @returns {String} Path for resources.
       */
      ProdConfiguration.prototype.getRoot = function() {
        return '/static'; 
      };
      
      return ProdConfiguration;
    }) ();
    QC.ProdConfiguration = ProdConfiguration;
    
    var LaneMQCControl = (function () {
      /**
       * Controller for individual lanes GUI.
       * @param index {Number} 
       * @param abstractConfiguration {Object} 
       * @memberof module:NPG/QC
       * @constructor
       */
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
        this.CONFIG_UNDECIDED           = 'Undecided'; //Initial outcome for widgets
        this.CONFIG_INITIAL             = 'initial';
      }
      
      /**
       * Change the outcome.
       */
      LaneMQCControl.prototype.updateOutcome = function(outcome) {
        var id_run = this.lane_control.data('id_run'); 
        var position = this.lane_control.data('position');
        var control = this;
        if(outcome != control.outcome) {
          //Show progress icon
          control.lane_control.find('.lane_mqc_working').html("<img src='"
              + this.abstractConfiguration.getRoot()
              + "/images/waiting.gif' width='10' height='10' title='Processing request.'>");
          //AJAX call.
          $.post(control.CONFIG_UPDATE_SERVICE, { id_run: id_run, position : position, new_oc : outcome}, function(data){
            var response = data;
          }, "json")
          .done(function() {
            switch (outcome) {
              case control.CONFIG_ACCEPTED_PRELIMINAR : control.setAcceptedPre(); break; 
              case control.CONFIG_REJECTED_PRELIMINAR : control.setRejectedPre(); break;
              case control.CONFIG_ACCEPTED_FINAL : control.setAcceptedFinal(); break;
              case control.CONFIG_REJECTED_FINAL : control.setRejectedFinal(); break;
              case control.CONFIG_UNDECIDED : control.setUndecided(); break;
            }
          })
          .fail(function(data) {
            window.console && console.log(data.responseJSON.message);
            jQuery("#ajax_status").append("<li class='failed_mqc'>" + data.responseJSON.message + "</li>");
          })
          .always(function(data){
            //Clear progress icon            
            control.lane_control.find('.lane_mqc_working').empty();
          });  
        } else {
          window.console && console.log("Noting to do.");
        }
      };
      
      /** 
       * Builds the gui controls necessary for the mqc operation and passes them to the view. 
       */ 
      LaneMQCControl.prototype.generateActiveControls = function() {
        var lane_control = this.lane_control;
        var self = this;
        var id_run = lane_control.data('id_run'); 
        var position = lane_control.data('position');
        var outcomes = [self.CONFIG_ACCEPTED_PRELIMINAR, 
                        self.CONFIG_UNDECIDED, 
                        self.CONFIG_REJECTED_PRELIMINAR];
        var labels = ["<img src='" + 
                      self.abstractConfiguration.getRoot() + 
                      "/images/tick.png' />", // for accepted
                      '&nbsp;&nbsp;&nbsp;', // for undecided
                      "<img src='" + 
                      self.abstractConfiguration.getRoot() + 
                      "/images/cross.png' />"]; // for rejected
        //Remove old working span
        self.lane_control.children(".lane_mqc_working").remove();
        //Create and add radios
        var name = 'radios_' + position;
        for(var i = 0; i < outcomes.length; i++) {
          var outcome = outcomes[i];
          var label = labels[i];
          var checked = null;
          if (self.outcome == outcome) {
            checked = true;
          }
          var radio = new NPG.QC.UI.MQCOutcomeRadio(position, outcome, label, name, checked);
          self.lane_control.append(radio.asObject());
        }
        self.addMQCFormat();
        self.lane_control.append($("<span class='lane_mqc_save'><img src='" + 
            self.abstractConfiguration.getRoot() + 
            "/images/padlock.png'></span>"));
        self.lane_control.children('.lane_mqc_save').off("click").on("click", function() {
          self.saveAsFinalOutcome();
        });
        if (self.outcome == self.CONFIG_UNDECIDED) {
          self.lane_control.children('.lane_mqc_save').hide();
        }
        //link the radio group to the update function
        $("input[name='" + name + "']").on("change", function () {
          self.updateOutcome(this.value);
        });
        //add a new working span
        self.lane_control.append("<span class='lane_mqc_working' />");
      };
      
      /** 
       * Checks the current outcome associated with this controller. If it is not final it will make it final
       * will update the value in the model with an async call and update the view. 
       */
      LaneMQCControl.prototype.saveAsFinalOutcome = function() {
        var control = this;
        if(this.outcome == this.CONFIG_UNDECIDED) {
          throw new Error('Invalid state');
        }
        if(this.outcome == this.CONFIG_ACCEPTED_PRELIMINAR) {
          this.updateOutcome(this.CONFIG_ACCEPTED_FINAL);
        }
        if(this.outcome == this.CONFIG_REJECTED_PRELIMINAR) {
          this.updateOutcome(this.CONFIG_REJECTED_FINAL);
        }
      };
      
      /** 
       * Methods to deal with background colours. 
       */
      LaneMQCControl.prototype.setAcceptedBG = function() {
        this.lane_control.parent().css("background-color", "#B5DAFF");
      };
      
      LaneMQCControl.prototype.setRejectedBG = function () {
        this.lane_control.parent().css("background-color", "#FFDDDD");
      };
      
      LaneMQCControl.prototype.removeMQCFormat = function () {
        this.lane_control.parent().children('.padded_anchor').removeClass("padded_anchor");
        this.lane_control.parent().removeClass('td_mqc');
      };
      
      LaneMQCControl.prototype.addMQCFormat = function () {
        this.lane_control.parent().addClass('td_mqc');
      };
      
      LaneMQCControl.prototype.setAcceptedPre = function() {
        this.outcome = this.CONFIG_ACCEPTED_PRELIMINAR;
        this.lane_control.children('.lane_mqc_save').show();
      };
      
      LaneMQCControl.prototype.setRejectedPre = function() {
        this.outcome = this.CONFIG_REJECTED_PRELIMINAR;
        this.lane_control.children('.lane_mqc_save').show();
      };
      
      LaneMQCControl.prototype.setAcceptedFinal = function() {
        this.outcome = this.CONFIG_ACCEPTED_FINAL;
        this.lane_control.empty();
        this.removeMQCFormat();
        this.setAcceptedBG();
      };
      
      LaneMQCControl.prototype.setRejectedFinal = function() {
        this.outcome = this.CONFIG_REJECTED_FINAL;
        this.lane_control.empty();
        this.removeMQCFormat();
        this.setRejectedBG();
      };
      
      LaneMQCControl.prototype.setUndecided = function() {
        this.outcome = this.CONFIG_UNDECIDED;
        this.lane_control.children('.lane_mqc_save').hide();
      };
      
      /** 
       * Links the individual object with an mqc controller so it can allow mqc of a lane.
       */
      LaneMQCControl.prototype.linkControl = function(lane_control) {
        lane_control.extra_handler = this;
        this.lane_control = lane_control;
        if ( typeof(lane_control.data(this.CONFIG_INITIAL)) === "undefined") {
          //If it does not have initial outcome
          this.outcome = this.CONFIG_UNDECIDED;
          this.generateActiveControls();
        } else if (lane_control.data(this.CONFIG_INITIAL) === this.CONFIG_ACCEPTED_PRELIMINAR 
            || lane_control.data(this.CONFIG_INITIAL) === this.CONFIG_REJECTED_PRELIMINAR
            || lane_control.data(this.CONFIG_INITIAL) === this.CONFIG_UNDECIDED) {
          //If previous outcome is preliminar.
          this.outcome = lane_control.data(this.CONFIG_INITIAL);
          this.generateActiveControls();
          switch (this.outcome){
            case this.CONFIG_ACCEPTED_PRELIMINAR : this.setAcceptedPre(); break;
            case this.CONFIG_REJECTED_PRELIMINAR : this.setRejectedPre(); break;
            case this.CONFIG_UNDECIDED : this.setUndecided(); break;
          }
        } else {
          this.loadBGFromInitial(lane_control);
        }
      };
      
      /**
       * Changes the background of the parent element depending on the initial outcome
       * of the lane.
       */
      LaneMQCControl.prototype.loadBGFromInitial = function (lane_control) {
        lane_control.extra_handler = this;
        this.lane_control = lane_control;
        switch (lane_control.data(this.CONFIG_INITIAL)){
          case this.CONFIG_ACCEPTED_FINAL : this.setAcceptedFinal(); break;
          case this.CONFIG_REJECTED_FINAL : this.setRejectedFinal(); break;
        }
        lane_control.find('.lane_mqc_working').empty();
      };
      
      return LaneMQCControl;
    }) ();
    QC.LaneMQCControl = LaneMQCControl;

    /**
     * Object with rules for general things about QC and its
     * user interface.
     * @memberof module:NPG/QC
     * @constructor
     */
    var RunMQCControl = (function () {
      function RunMQCControl(abstractConfiguration) {
        this.abstractConfiguration = abstractConfiguration;
        this.mqc_run_data          = null;
        this.QC_IN_PROGRESS        = 'qc in progress';
        this.QC_ON_HOLD            = 'qc on hold';
      }
      
      /**
       * Validates qc conditions and if everything is ready for qc it will call the 
       * target function passing parameters. If not qc ready will call mop function.
       * @param mqc_run_data {Object} Run status data
       * @param lanes {array} lanes
       * @param targetFunction {function} What to run if state for MQC
       * @param mopFunction {function} What to run if not state for MQC
       * @returns the result of running the functions.
       */
      RunMQCControl.prototype.initQC = function (mqc_run_data, lanes, targetFunction, mopFunction) {
        var result = null;
        if(typeof(mqc_run_data) !== "undefined" && mqc_run_data != null) { //There is a data object
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
      
      /**
       * Checks all conditions related with the user in session and the
       * status of the run. Validates the user has privileges, has role,
       * the run is in correct status and the user in session is the
       * same as the user who took the QCing.
       * @param mqc_run_data {Object} Run status data
       */
      RunMQCControl.prototype.isStateForMQC = function (mqc_run_data) {
        if(typeof(mqc_run_data) === "undefined" 
            || mqc_run_data == null) {
          throw new Error("invalid arguments");
        }

        var result = typeof(mqc_run_data.taken_by) !== "undefined"  //Data object has all values needed.
          && typeof(mqc_run_data.current_user)!== "undefined"
          && typeof(mqc_run_data.has_manual_qc_role)!== "undefined"
          && typeof(mqc_run_data.current_status_description)!== "undefined"
          && mqc_run_data.taken_by == mqc_run_data.current_user /* Session & qc users are the same */
          && mqc_run_data.has_manual_qc_role == 1 /* Returns '' if not */
          && (mqc_run_data.current_status_description == this.QC_IN_PROGRESS
            || mqc_run_data.current_status_description == this.QC_ON_HOLD)
        return result;
      };
      
      /**
       * Iterates through lanes and shows the outcomes
       * @param mqc_run_data
       * @param lanes
       */
      RunMQCControl.prototype.showMQCOutcomes = function (mqc_run_data, lanes) {
        if(typeof(mqc_run_data) === "undefined" 
            || mqc_run_data == null 
            || typeof(lanes) === "undefined" 
            || lanes == null) {
          throw new Error("invalid arguments");
        }
        var self = this;

        for(var i = 0; i < lanes.length; i++) {
          lanes[i].children('.lane_mqc_control').each(function(j, obj){
            $(obj).html("<span class='lane_mqc_working'><img src='" 
                + self.abstractConfiguration.getRoot() 
                + "/images/waiting.gif' width='10' height='10' title='Processing request.'></span>");
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
            lanes[i].children('.padded_anchor').removeClass("padded_anchor");
          }
        }
      };
      
      /**
       * Update values in lanes with values from REST. Then link the lane
       * to a controller. The lane controller will update with widgets or
       * with proper background.
       */
      RunMQCControl.prototype.prepareLanes = function (mqc_run_data, lanes) {
        if(typeof(mqc_run_data) === "undefined" 
            || mqc_run_data == null 
            || typeof(lanes) === "undefined" 
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
      
      /**
       * Validates if lanes' outcome returned from DWH and MQC match during manual QC.
       * Only checks in case there is an outcome in DWH, meaning there should be an 
       * outcome in manual QC.
       * 
       * @param lanesWithBG {array} Lanes with background.
       * @param mqc_run_data {Object} Value object with the state data for the run.
       * 
       *  @returns A value object with two properties
       *  outcome: true/false for the result of the match. 
       *  position: null if matching, number of the first lane where there was a missmatch
       *   otherwise.
       */
      RunMQCControl.prototype.laneOutcomesMatch = function (lanesWithBG, mqc_run_data) {
        if(typeof(lanesWithBG) === "undefined" 
            || lanesWithBG == null 
            || typeof(mqc_run_data) === "undefined"
            || mqc_run_data == null) {
          throw new Error("invalid arguments");
        }
        var result = new Object();
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

    var RunTitleParser = (function () {
      /**
       * Object to deal with id_run parsing from text.
       * @memberof module:NPG/QC
       * @constructor
       */
      function RunTitleParser() {
        this.reId = /^Results for run ([0-9]+) \(current run status:/;
      }

      /**
       * Parses the id_run from the title (or text) passed as param.
       * It looks for first integer using a regexp.
       * 
       * "^Results for run ([0-9]+) \(current run status:"
       * 
       * @param text {String} Text to parse.
       * 
       * @returns the first match for the execution of the regexp, 
       * which should be the id_run for a successful execution.
       */
      RunTitleParser.prototype.parseIdRun = function (text) {
        if(typeof(text) === "undefined" || text == null) {
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
    
    /**
     * @module NPG/QC/UI
     */
    (function(UI) {
      var MQCOutcomeRadio = (function() {
        /**
         * Widget to select the different outcomes of a lane. Internally
         * implemented as a radio.
         * @memberof module:NPG/QC/UI
         * @constructor
         * @param {String} id_pre - prefix for the id.
         * @param {String} outcome - outcome as string.
         * @param {String} label - HTML for the label of the radio (an image 
         * for example).
         * @param {String} name - for the radio. Using the same name for 
         * different radios groups them together.
         * @param {Object} checked - if checked is not undefined the radio 
         * option will be marked as "checked" otherwise it will not be checked.
         * @author jmtc
         */
        MQCOutcomeRadio = function(id_pre, outcome, label, group, checked) {
          this.id_pre = id_pre;
          this.outcome = outcome;
          this.label = label;
          if (typeof (group) === "undefined" || group == null) {
            this.group = 'radios';
          } else {
            this.group = group;
          }
          if (typeof (checked) === "undefined" || checked == null) {
            this.checked = '';
          } else {
            this.checked = ' checked ';
          }
        }

        /**
         * Generates the HTML code of the radio and the label for this object.
         * @returns {String} HTML code representation.
         */
        MQCOutcomeRadio.prototype.asHtml = function() {
          var self = this;
          var internal_id = "radio_" + self.id_pre + "_" + self.outcome + "";
          var label = "<label for='" + internal_id + "'>" + self.label
              + "</label>";

          var html = "<input type='radio' id='" + internal_id + "' "
              + "name='" + self.group + "' value='" + self.outcome + "'"
              + self.checked + ">" + label;
          return html;
        }
        
        /**
         * Generates the HTML code of the radio and the label for this object, wraps
         * in JQuery object and returns
         * @returns {Object} JQuery object.
         */
        MQCOutcomeRadio.prototype.asObject = function() {
          var self = this;
          var obj = $(self.asHtml());
          return obj;
        };
        return MQCOutcomeRadio;
      })();
      UI.MQCOutcomeRadio = MQCOutcomeRadio;
    })(NPG.QC.UI || (NPG.QC.UI = {}));
    var UI = NPG.QC.UI;
  }) (NPG.QC || (NPG.QC = {}));
  var QC = NPG.QC;
}) (NPG || (NPG = {}));

/*
 * Check current state of the lanes. If current state is ready for QC, get
 * information from the page and prepare a VO object. Update the lanes with GUI
 * controls when necessary.
 */
function getQcState(mqc_run_data, runMQCControl, lanes) {
  //Show working icons
  for(var i = 0; i < lanes.length; i++) {
    lanes[i].children('a').addClass('padded_anchor');
    lanes[i].children('.lane_mqc_control').each(function(j, obj){
      $(obj).html("<span class='lane_mqc_working'><img src='/static/images/waiting.gif' title='Processing request.'></span>");
    });
  }
  
  runMQCControl.prepareLanes(mqc_run_data, lanes);
}

