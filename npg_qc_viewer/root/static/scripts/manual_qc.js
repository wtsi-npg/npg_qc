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
/* globals $: false, window: false, document : false */
"use strict";
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

    QC.launchManualQCProcesses = function () {
      // Getting the run_id from the title of the page using the qc part too.
      var runTitleParserResult = new NPG.QC.RunTitleParser().parseIdRun($(document)
                                                            .find("title")
                                                            .text());
      //If id_run
      if(typeof(runTitleParserResult) !== 'undefined' && runTitleParserResult != null) {
        var id_run = runTitleParserResult.id_run;
        var prodConfiguration = new NPG.QC.ProdConfiguration();
        //Read information about lanes from page.
        var lanes = []; //Lanes without previous QC, blank BG
        var control;

        if (runTitleParserResult.isRunPage) {
          var lanesWithBG = []; //Lanes with previous QC, BG with colour
          control = new NPG.QC.RunPageMQCControl(prodConfiguration);
          control.parseLanes(lanes, lanesWithBG);
          control.prepareMQC(id_run, lanes, lanesWithBG);
        } else {
          var position = runTitleParserResult.position;
          control = new NPG.QC.LanePageMQCControl(prodConfiguration);
          control.parseLanes(lanes);
          control.prepareMQC(id_run, position, lanes);
        }
      }
    };

    var MQCControl = (function () {
      function MQCControl(abstractConfiguration) {
        this.outcome               = null;  // Current outcome (Is updated when linked to an object in the view)
        this.lane_control          = null;  // Container linked to this controller
        this.abstractConfiguration = abstractConfiguration;

        this.CONFIG_ACCEPTED_PRELIMINARY = 'Accepted preliminary';
        this.CONFIG_REJECTED_PRELIMINARY = 'Rejected preliminary';
        this.CONFIG_ACCEPTED_FINAL       = 'Accepted final';
        this.CONFIG_REJECTED_FINAL       = 'Rejected final';
        this.CONFIG_UNDECIDED            = 'Undecided'; //Initial outcome for widgets
        this.CONFIG_INITIAL              = 'initial';
        this.CONFIG_CONTROL_TAG          = 'gui_controller'; //For link in DOM

        //container names
        this.LANE_MQC_WORKING           = 'lane_mqc_working';
        this.LANE_MQC_WORKING_CLASS     = '.' + this.LANE_MQC_WORKING;

        //Variable names for data from the DOM
        this.DATA_ID_RUN                = 'id_run';
        this.DATA_POSITION              = 'position';
        this.DATA_TAG_INDEX             = 'tag_index';

        this.id_run    = null;
        this.position  = null;
      }

      /**
       * Checks the current outcome associated with this controller. If it is not final it will make it final
       * will update the value in the model with an async call and update the view.
       */
      MQCControl.prototype.saveAsFinalOutcome = function() {
        var control = this;
        if(this.outcome == this.CONFIG_UNDECIDED) {
          throw new Error('Error: Invalid state');
        }
        if(this.outcome == this.CONFIG_ACCEPTED_PRELIMINARY) {
          this.updateOutcome(this.CONFIG_ACCEPTED_FINAL);
        }
        if(this.outcome == this.CONFIG_REJECTED_PRELIMINARY) {
          this.updateOutcome(this.CONFIG_REJECTED_FINAL);
        }
      };

      /**
       * Methods to deal with background colours.
       */
      MQCControl.prototype.removeAllQCOutcomeCSSClasses = function () {
        this.lane_control.parent()
                         .css("background-color", "#ffffff")
                         .removeClass(function (index, css) {
          return (css.match (/qc_outcome[a-zA-Z_]+/gi) || []).join(' ');
        });
      };

      MQCControl.prototype.setAcceptedBG = function() {
        this.removeAllQCOutcomeCSSClasses();
        this.lane_control.parent().addClass('qc_outcome_accepted_final');
      };

      MQCControl.prototype.setRejectedBG = function () {
        this.removeAllQCOutcomeCSSClasses();
        this.lane_control.parent().addClass('qc_outcome_rejected_final');
      };

      MQCControl.prototype.removeMQCFormat = function () {
        this.lane_control.parent().removeClass('td_mqc');
        this.lane_control.parent().css('text-align', 'center'); // For firefox
      };

      MQCControl.prototype.addMQCFormat = function () {
        this.lane_control.parent().css('text-align', 'left'); // For firefox
        this.lane_control.parent().addClass('td_mqc');
      };

      MQCControl.prototype.setAcceptedPre = function() {
        this.outcome = this.CONFIG_ACCEPTED_PRELIMINARY;
        this.removeAllQCOutcomeCSSClasses();
        this.lane_control.parent().css("background-color", "#E5F2FF");
        this.lane_control.children('.lane_mqc_save').show();
      };

      MQCControl.prototype.setRejectedPre = function() {
        this.outcome = this.CONFIG_REJECTED_PRELIMINARY;
        this.removeAllQCOutcomeCSSClasses();
        this.lane_control.parent().css("background-color", "#FFDDDD");
        this.lane_control.children('.lane_mqc_save').show();
      };

      MQCControl.prototype.setAcceptedFinal = function() {
        this.outcome = this.CONFIG_ACCEPTED_FINAL;
        this.lane_control.empty();
        this.removeMQCFormat();
        this.setAcceptedBG();
      };

      MQCControl.prototype.setRejectedFinal = function() {
        this.outcome = this.CONFIG_REJECTED_FINAL;
        this.lane_control.empty();
        this.removeMQCFormat();
        this.setRejectedBG();
      };

      MQCControl.prototype.setUndecided = function() {
        this.outcome = this.CONFIG_UNDECIDED;
        this.removeAllQCOutcomeCSSClasses();
        this.lane_control.children('.lane_mqc_save').hide();
      };

      /**
       * Switch the outcome and adjust the view accordingly
       * @param outcome new outcome for the control.
       */
      MQCControl.prototype.updateView = function(outcome) {
        switch (outcome) {
          case this.CONFIG_ACCEPTED_PRELIMINARY : this.setAcceptedPre(); break;
          case this.CONFIG_REJECTED_PRELIMINARY : this.setRejectedPre(); break;
          case this.CONFIG_ACCEPTED_FINAL       : this.setAcceptedFinal(); break;
          case this.CONFIG_REJECTED_FINAL       : this.setRejectedFinal(); break;
          case this.CONFIG_UNDECIDED            : this.setUndecided(); break;
        }
      };

      /**
       * What to do after getting a fail during the json request to update
       * the outcome
       * @param data Data from response
       */
      MQCControl.prototype.processAfterFail = function(data) {
        var self = this;
        self.lane_control.children('input:radio').val([self.outcome]);
        var errorMessage = null;
        if (typeof(data.responseJSON) !== 'undefined') {
          errorMessage = data.responseJSON.message;
        } else {
          errorMessage = data.statusText + ": Detailed response in console.";
          window.console && console.log(data.responseText);
        }
        new NPG.QC.UI.MQCErrorMessage(errorMessage).toConsole().display();
      };

      /**
       * Links the individual object with an mqc controller so it can allow mqc of a lane.
       */
      MQCControl.prototype.linkControl = function(lane_control) {
        lane_control.data(this.CONFIG_CONTROL_TAG, this);
        this.lane_control = lane_control;
        if ( typeof(lane_control.data(this.CONFIG_INITIAL)) === "undefined") {
          //If it does not have initial outcome
          this.outcome = this.CONFIG_UNDECIDED;
          this.generateActiveControls();
        } else if (lane_control.data(this.CONFIG_INITIAL) === this.CONFIG_ACCEPTED_PRELIMINARY
            || lane_control.data(this.CONFIG_INITIAL) === this.CONFIG_REJECTED_PRELIMINARY
            || lane_control.data(this.CONFIG_INITIAL) === this.CONFIG_UNDECIDED) {
          //If previous outcome is preliminar.
          this.outcome = lane_control.data(this.CONFIG_INITIAL);
          this.generateActiveControls();
          switch (this.outcome){
            case this.CONFIG_ACCEPTED_PRELIMINARY : this.setAcceptedPre(); break;
            case this.CONFIG_REJECTED_PRELIMINARY : this.setRejectedPre(); break;
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
      MQCControl.prototype.loadBGFromInitial = function (lane_control) {
        lane_control.data(this.CONFIG_CONTROL_TAG, this);
        this.lane_control = lane_control;
        switch (lane_control.data(this.CONFIG_INITIAL)){
          case this.CONFIG_ACCEPTED_FINAL : this.setAcceptedFinal(); break;
          case this.CONFIG_REJECTED_FINAL : this.setRejectedFinal(); break;
        }
        lane_control.find(this.LANE_MQC_WORKING_CLASS).empty();
      };

      return MQCControl;
    }) ();
    QC.MQCControl = MQCControl;

    var LaneMQCControl = (function () {
      /**
       * Controller for individual lanes GUI.
       * @param abstractConfiguration {Object}
       * @memberof module:NPG/QC
       * @constructor
       */
      function LaneMQCControl(abstractConfiguration) {
        NPG.QC.MQCControl.call(this, abstractConfiguration);
        this.CONFIG_UPDATE_SERVICE = "/mqc/update_outcome_lane";
      }

      LaneMQCControl.prototype = new NPG.QC.MQCControl();

      /**
       * Change the outcome.
       */
      LaneMQCControl.prototype.updateOutcome = function(outcome) {
        var self = this;
        if(outcome != self.outcome) {
          //Show progress icon
          self.lane_control.find(self.LANE_MQC_WORKING_CLASS).html("<img src='"
              + this.abstractConfiguration.getRoot()
              + "/images/waiting.gif' width='10' height='10' title='Processing request.'>");
          //AJAX call.
          $.post(self.CONFIG_UPDATE_SERVICE, { id_run   : self.id_run,
                                               position : self.position,
                                               new_oc   : outcome}, function(data){
          }, "json")
          .done(function() {
            self.updateView(outcome);
          })
          .fail(function(data) {
            self.processAfterFail(data);
          })
          .always(function(){
            //Clear progress icon
            self.lane_control.find(self.LANE_MQC_WORKING_CLASS).empty();
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
        self.id_run   = lane_control.data(this.DATA_ID_RUN);
        self.position = lane_control.data(this.DATA_POSITION);
        var outcomes = [self.CONFIG_ACCEPTED_PRELIMINARY,
                        self.CONFIG_UNDECIDED,
                        self.CONFIG_REJECTED_PRELIMINARY];
        var labels = ["<img src='" +
                      self.abstractConfiguration.getRoot() +
                      "/images/tick.png'  title='Mark lane as preliminary pass'/>", // for accepted
                      '&nbsp;&nbsp;&nbsp;', // for undecided
                      "<img src='" +
                      self.abstractConfiguration.getRoot() +
                      "/images/cross.png' title='Mark lane as preliminary fail'/>"]; // for rejected
        //Remove old working span
        self.lane_control.children(self.LANE_MQC_WORKING_CLASS).remove();
        //Create and add radios
        var id_pre = self.id_run + '_' + self.position;
        var name = 'radios_' + id_pre;
        for(var i = 0; i < outcomes.length; i++) {
          var outcome = outcomes[i];
          var label = labels[i];
          var checked = null;
          if (self.outcome == outcome) {
            checked = true;
          }
          var radio = new NPG.QC.UI.MQCOutcomeRadio(id_pre, outcome, label, name, checked);
          self.lane_control.append(radio.asObject());
        }
        self.addMQCFormat();
        self.lane_control.append($("<span class='lane_mqc_button lane_mqc_save' title='Save current outcome as final (can not be changed again)'><img src='" +
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

      return LaneMQCControl;
    }) ();

    QC.LaneMQCControl = LaneMQCControl;

    /* Plex */
    var LibraryMQCControl = (function () {
      /**
       * Controller for individual plexes GUI.
       * @param abstractConfiguration {Object}
       * @memberof module:NPG/QC
       * @constructor
       */
      function LibraryMQCControl(abstractConfiguration) {
        NPG.QC.MQCControl.call(this, abstractConfiguration);
        this.CONFIG_UPDATE_SERVICE = "/mqc/update_outcome_library";

        this.tag_index = null;
      }

      LibraryMQCControl.prototype = new NPG.QC.MQCControl();

      /**
       * Change the outcome.
       */
      LibraryMQCControl.prototype.updateOutcome = function(outcome) {
        var self = this;
        if(outcome != self.outcome) {
          //Show progress icon
          self.lane_control.find(self.LANE_MQC_WORKING_CLASS).html("<img src='"
              + this.abstractConfiguration.getRoot()
              + "/images/waiting.gif' width='10' height='10' title='Processing request.'>");
          //AJAX call.
          $.post(self.CONFIG_UPDATE_SERVICE, { id_run    : self.id_run,
                                               position  : self.position,
                                               tag_index : self.tag_index,
                                               new_oc    : outcome}, function(data){
            var response = data;
          }, "json")
          .done(function() {
            self.updateView(outcome);
          })
          .fail(function(data) {
            self.processAfterFail(data);
          })
          .always(function(data){
            //Clear progress icon
            self.lane_control.find(self.LANE_MQC_WORKING_CLASS).empty();
          });
        } else {
          window.console && console.log("Noting to do.");
        }
      };

      /**
       * Builds the gui controls necessary for the mqc operation and passes them
       * to the view.
       */
      LibraryMQCControl.prototype.generateActiveControls = function() {
        var lane_control = this.lane_control;
        var self = this;
        self.id_run    = lane_control.data(this.DATA_ID_RUN);
        self.position  = lane_control.data(this.DATA_POSITION);
        self.tag_index = lane_control.data(this.DATA_TAG_INDEX);
        var outcomes  = [self.CONFIG_ACCEPTED_PRELIMINARY,
                         self.CONFIG_UNDECIDED,
                         self.CONFIG_REJECTED_PRELIMINARY];
        var labels    = ["<img src='" +
                         self.abstractConfiguration.getRoot() +
                         "/images/tick.png'  title='Mark lane as preliminary pass'/>", // for accepted
                         '&nbsp;&nbsp;&nbsp;', // for undecided
                         "<img src='" +
                         self.abstractConfiguration.getRoot() +
                         "/images/cross.png' title='Mark lane as preliminary fail'/>"]; // for rejected
        //Remove old working span
        self.lane_control.children(self.LANE_MQC_WORKING_CLASS).remove();
        //Create and add radios
        var id_pre = self.id_run + '_' + self.position + '_' + self.tag_index;
        var name = 'radios_' + id_pre;
        for(var i = 0; i < outcomes.length; i++) {
          var outcome = outcomes[i];
          var label = labels[i];
          var checked = null;
          if (self.outcome == outcome) {
            checked = true;
          }
          var radio = new NPG.QC.UI.MQCOutcomeRadio(id_pre, outcome, label, name, checked);
          self.lane_control.append(radio.asObject());
        }
        self.addMQCFormat();
        //link the radio group to the update function
        $("input[name='" + name + "']").on("change", function () {
          self.updateOutcome(this.value);
        });
        //add a new working span
        self.lane_control.append("<span class='lane_mqc_working' />");
      };

      LibraryMQCControl.prototype.removeMQCFormat = function () {
        this.lane_control.parent().removeClass('td_library_mqc');
        this.lane_control.parent().css('text-align', 'center'); // For firefox
      };

      LibraryMQCControl.prototype.addMQCFormat = function () {
        this.lane_control.parent().css('text-align', 'left'); // For firefox
        this.lane_control.parent().addClass('td_library_mqc');
      };

      LibraryMQCControl.prototype.setAcceptedFinal = function() {
        this.outcome = this.CONFIG_ACCEPTED_FINAL;
        this.lane_control.empty();
        this.removeMQCFormat();
      };

      LibraryMQCControl.prototype.setRejectedFinal = function() {
        this.outcome = this.CONFIG_REJECTED_FINAL;
        this.lane_control.empty();
        this.removeMQCFormat();
      };

      return LibraryMQCControl;
    }) ();
    QC.LibraryMQCControl = LibraryMQCControl;
    /* Plex */

    var PageMQCControl = (function () {
      function PageMQCControl (abstractConfiguration) {
        this.abstractConfiguration = abstractConfiguration;
        this.mqc_run_data          = null;
        this.QC_IN_PROGRESS        = 'qc in progress';
        this.QC_ON_HOLD            = 'qc on hold';
        this.ACCEPTED_FINAL        = 'Accepted final';
        this.REJECTED_FINAL        = 'Rejected final';
      }

      /**
       * Returns true if the user in session matches the user QCing the run and
       * the user has manual_qc role
       * @param mqc_run_data Transfer object with the mqc data. Must include
       * values for taken_by, current_user and has_manual_qc_role
       * @returns {Boolean}
       */
      PageMQCControl.prototype.checkUserInSession = function (mqc_run_data) {
        var result = typeof(mqc_run_data.taken_by) !== "undefined"  //Data object has all values needed.
                     && typeof(mqc_run_data.current_user)!== "undefined"
                     && typeof(mqc_run_data.has_manual_qc_role)!== "undefined"
                     && mqc_run_data.taken_by == mqc_run_data.current_user /* Session & qc users are the same */
                     && mqc_run_data.has_manual_qc_role == 1 /* Returns '' if not */;
        return result;
      };

      /**
       * Returns true if the run is currently identified as qc in progress or
       * qc on hold.
       * @param mqc_run_data Transfer object with the mqc data. Must contain a
       * value for current_status_description.
       * @returns {Boolean}
       */
      PageMQCControl.prototype.checkRunStatus = function (mqc_run_data) {
        var result = typeof(mqc_run_data.current_status_description)!== "undefined"
                     && (mqc_run_data.current_status_description == this.QC_IN_PROGRESS
                       || mqc_run_data.current_status_description == this.QC_ON_HOLD);
        return result;
      };

      /**
       * Checks if the field passed as parameter is not undefined and different
       * from null. Throws an Error otherwise.
       * @param field what to check.
       */
      PageMQCControl.prototype.validateRequired = function (field){
        if(typeof(field) === "undefined"
            || field == null) {
          throw new Error("Error: Invalid arguments.");
        }
        return;
      };

      /**
       * Find "lanes" (html rows) from the page and split them in two groups
       * based on the QC result they already have (checked by using the css
       * class of the row). Adds the lanes to the corresponding array.
       * @param lanes Lanes without background
       * @param lanesWithBG Lanes with background (pass or fail)
       */
      PageMQCControl.prototype.parseLanes = function (lanes, lanesWithBG) {
        //Select non-qced lanes.
        $('.lane_mqc_control').each(function (i, obj) {
          obj = $(obj);
          var parent = obj.parent();
          //Not considering lanes previously marked as passes/failed
          if(parent.hasClass('qc_outcome_accepted_final') || parent.hasClass('qc_outcome_rejected_final')) {
            lanesWithBG.push(parent);
          } else {
            lanes.push(parent);
          }
        });
        return;
      };

      return PageMQCControl;
    }) ();
    QC.PageMQCControl = PageMQCControl;

    var LanePageMQCControl = (function () {
      function LanePageMQCControl (abstractConfiguration){
        NPG.QC.PageMQCControl.call(this, abstractConfiguration);
        this.DATA_TAG_INDEX       = 'tag_index';
        this.REST_SERVICE         = '/mqc/mqc_libraries/';
        this.CURRENT_LANE_OUTCOME = 'current_lane_outcome';
      }

      LanePageMQCControl.prototype = new NPG.QC.PageMQCControl();

      LanePageMQCControl.prototype.parseLanes = function (lanes) {
        $('.lane_mqc_control').each(function (i, obj) {
          var parent = $(obj).parent();
          lanes.push(parent);
        });
        return;
      };

      LanePageMQCControl.prototype.initQC = function (mqc_run_data, plexes, targetFunction, mopFunction) {
        var result = null;
        var self = this;
        //Need both a data object and eligible plexes
        if(typeof(mqc_run_data) !== "undefined" && mqc_run_data != null) {
          this.mqc_run_data = mqc_run_data; //Do we need this assignment?
          self.addAllPaddings();
          result = targetFunction(mqc_run_data, this, plexes);
        } else {
          result = mopFunction();
        }
        return result;
      };

      /**
       * Returns true if the current 'lane' (row in the table) is does not have
       * a final outcome.
       * @param mqc_run_data Transfer object with the mqc data. Must include a
       * current_lane_outcome.
       * @returns {Boolean}
       */
      LanePageMQCControl.prototype.checkLaneStatus = function (mqc_run_data) {
        var result = typeof(mqc_run_data.current_lane_outcome) !== "undefined"
                     && mqc_run_data.current_lane_outcome != this.ACCEPTED_FINAL
                     && mqc_run_data.current_lane_outcome != this.REJECTED_FINAL;
        return result;
      };

      /**
       * Returns true if the number of libraries in the page is less or equal to
       * the maximum number of libraries to be manualy QC'ed
       * @param mqc_run_data Transfer object with the manual qc data, must
       * include an array of tags.
       * @returns {Boolean}
       */
      LanePageMQCControl.prototype.checkLibLimit = function (mqc_run_data) {
        var result = typeof(mqc_run_data.qc_tags)!== "undefined"
                     && typeof(mqc_run_data.mqc_lib_limit)!== "undefined"
                     && mqc_run_data.qc_tags.length <= mqc_run_data.mqc_lib_limit;

        if(!result) {
          new NPG.QC.UI.MQCInfoMessage(
            'Too many plexes, lane level manual QC only.').toConsole().display();
        }
        return result;
      };

      /**
       * Checks all conditions related with the user in session and the
       * status of the run. Validates the user has privileges, has role,
       * the run is in correct status and the user in session is the
       * same as the user who took the MQCing. The number of libraries is bellow
       * the limit for manual QC.
       * @param mqc_run_data {Object} Run status data
       */
      LanePageMQCControl.prototype.isStateForMQC = function (mqc_run_data) {
        this.validateRequired(mqc_run_data);

        var result = this.checkUserInSession(mqc_run_data)
          && this.checkRunStatus(mqc_run_data)
          && this.checkLaneStatus(mqc_run_data)
          && this.checkLibLimit(mqc_run_data); //Short-Circuit AND makes sure we check this bit only if necessary, displaying message only when necessary.
        return result;
      };

      /**
       * Uses the data from mqc_run_data (list of qc_tags) to filter the
       * array of lanes from the page. It creates a new array which contains
       * only lanes with tag_indexes which need to be qc'ed (without
       * tag_index in {0, phix}). Internally it also creates an array of lanes
       * which appear in the page but are non_qc_tags. It validates number of
       * lanes processed and number of tags qc + non qc. They should match. If
       * they don't match, generates an error message and throws an Error.
       * @param mqc_run_data data from REST
       * @param lanes dom elements from page
       * @returns {Array}
       */
      LanePageMQCControl.prototype.onlyQCAble = function (mqc_run_data, lanes) {
        this.validateRequired(mqc_run_data);
        if(typeof(lanes) === "undefined"
            || lanes == null) {
          throw new Error("Error: Invalid arguments");
        }
        var lanes_qc_temp = [];
        var lanes_non_qc_temp = [];
        var lanes_checked = 0;
        for(var i = 0; i < lanes.length; i++) {
          var lane = lanes[i];
          var cells = lane.children('.lane_mqc_control');
          for(var j = 0; j < cells.length; j++) {
            var obj = $(cells[j]); //Wrap as an jQuery object.
            var tag_index = obj.data(this.DATA_TAG_INDEX);
            tag_index = String(tag_index);
            if(tag_index !== '') {
              lanes_checked++;
              //tag_index is qc-able
              if($.inArray(tag_index, mqc_run_data.qc_tags) != -1) {
                lanes_qc_temp.push(lane);
              } else {
                if ($.inArray(tag_index, mqc_run_data.non_qc_tags) != -1) {
                  lanes_non_qc_temp.push(lane);
                }
              }
            }
          }
        }
        if(lanes_qc_temp.length + lanes_non_qc_temp.length != lanes_checked) {
          var errorMessage = 'Error: Conflicting data when comparing libraries from LIMS Warehouse and QC database.';
          new NPG.QC.UI.MQCErrorMessage(errorMessage).toConsole().display();
          throw new Error("Error: Conflicting data from LIMS DWH and QC database.");
        }

        return lanes_qc_temp;
      };

      LanePageMQCControl.prototype.removeAllPaddings = function () {
        $('.lane_mqc_control').css("padding-right", "0px");
        $('.lane_mqc_control').css("padding-left", "0px");
        $('.library_mqc_overall_controls').css("padding-right", "0px");
      };

      LanePageMQCControl.prototype.addAllPaddings = function () {
        $('.lane_mqc_control').css("padding-right", "5px");
        $('.lane_mqc_control').css("padding-left", "10px");
        $('.library_mqc_overall_controls').css("padding-left", "15px");
      };

      /**
       * Use data from the page to make the first call to REST. Finds rows which
       * need qc, inits qc for those rows. If it is not state for MQC it updates
       * the view with current MQC values.
       * @param id_run
       * @param position
       * @param lanes
       */
      LanePageMQCControl.prototype.prepareMQC = function (id_run, position, lanes) {
        var self = this;
        var jqxhr = $.ajax({
          url: self.REST_SERVICE + id_run + '_' + position,
          cache: false
        }).done(function() {
          var mqc_run_data = jqxhr.responseJSON;
          for(var i = 0; i < lanes.length; i++) {
            lanes[i].children('.lane_mqc_control').each(function(j, obj) {
              obj = $(obj);
            });
          }

          //Filter lanes for qc using data from REST
          var onlyQCAble = self.onlyQCAble(mqc_run_data, lanes);

          if(self.isStateForMQC(mqc_run_data) && onlyQCAble.length > 0) {
            var overallControls = new NPG.QC.UI.MQCLibraryOverallControls();
            overallControls.setupControls();
            overallControls.init(onlyQCAble);

            self.initQC(mqc_run_data, onlyQCAble,
              function (mqc_run_data, self, onlyQCAble) {
                //Show working icons
                for(var i = 0; i < onlyQCAble.length; i++) {
                  onlyQCAble[i].children('.lane_mqc_control').each(function(j, obj){
                    $(obj).html("<span class='lane_mqc_working'><img src='/static/images/waiting.gif' title='Processing request.'></span>");
                  });
                }
                self.prepareLanes(mqc_run_data, onlyQCAble);
              },
              function () { //There is no mqc because of problems with data
                self.removeAllPaddings();
                return;
              }
            );
          } else {
            self.removeAllPaddings();
          }
        }).fail(function(jqXHR, textStatus, errorThrown) {
          var errorMessage;
          if (jqXHR.responseJSON) {
            errorMessage = jqXHR.responseJSON.error;
          } else {
            errorMessage = errorThrown + " " + textStatus;
          }
          new NPG.QC.UI.MQCErrorMessage(errorMessage).toConsole().display();
        }).always(function(data){
          //Clear progress icon
          $('.lane_mqc_working').empty();
        });
        return;
      };

      LanePageMQCControl.prototype.prepareLanes = function (mqc_run_data, lanes) {
        this.validateRequired(mqc_run_data);
        if(typeof(lanes) === "undefined" || lanes == null) {
          throw new Error("Error: Invalid arguments");
        }
        var self = this;

        $('.lane, .tag_info').css("background-color", "#ffffff")
                  .removeClass(function (index, css) {
          return (css.match (/qc_outcome[a-zA-Z_]+/gi) || []).join(' ');
        });

        for(var i = 0; i < lanes.length; i++) {
          var cells = lanes[i].children('.lane_mqc_control');
          for(var j = 0; j < cells.length; j++) {
            var obj = $(cells[j]); //Wrap as an jQuery object.
            //Plex from row.
            var tag_index = obj.data(this.DATA_TAG_INDEX);
            //Filling previous outcomes
            if('qc_plex_status' in mqc_run_data && tag_index in mqc_run_data.qc_plex_status) {
              //From REST
              var current_status = mqc_run_data.qc_plex_status[tag_index];
              //To html element, LaneControl will render.
              obj.data('initial', current_status);
            }
            //Set up mqc controlers and link them to the individual lanes.
            var c = new NPG.QC.LibraryMQCControl(self.abstractConfiguration);
            c.linkControl(obj);
          }
        }
      };

      return LanePageMQCControl;
    }) ();
    QC.LanePageMQCControl = LanePageMQCControl;

    /**
     * Object with rules for general things about QC and its
     * user interface.
     * @memberof module:NPG/QC
     * @constructor
     */
    var RunPageMQCControl = (function () {
      function RunPageMQCControl(abstractConfiguration) {
        NPG.QC.PageMQCControl.call(this, abstractConfiguration);
        this.REST_SERVICE = '/mqc/mqc_runs/';
      }

      RunPageMQCControl.prototype = new NPG.QC.PageMQCControl();

      RunPageMQCControl.prototype.removeAllPaddings = function () {
        $('.lane_mqc_control').css("padding-right", "0px");
        $('.lane_mqc_control').css("padding-left", "0px");
      };

      RunPageMQCControl.prototype.addAllPaddings = function () {
        $('.lane_mqc_control').css("padding-right", "5px");
        $('.lane_mqc_control').css("padding-left", "10px");
      };

      /**
       * Validates qc conditions and if everything is ready for qc it will call the
       * target function passing parameters. If not qc ready will call mop function.
       * @param mqc_run_data {Object} Run status data
       * @param lanes {array} lanes
       * @param targetFunction {function} What to run if state for MQC
       * @param mopFunction {function} What to run if not state for MQC
       * @returns the result of running the functions.
       */
      RunPageMQCControl.prototype.initQC = function (mqc_run_data, lanes, targetFunction, mopFunction) {
        var result = null;
        var self = this;
        if(typeof(mqc_run_data) !== "undefined" && mqc_run_data != null) { //Need data object
          this.mqc_run_data = mqc_run_data;
          if(self.isStateForMQC(mqc_run_data)) {
            self.addAllPaddings();
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
      RunPageMQCControl.prototype.isStateForMQC = function (mqc_run_data) {
        this.validateRequired(mqc_run_data);
        var result = this.checkUserInSession(mqc_run_data)
                     && this.checkRunStatus(mqc_run_data);
        return result;
      };

      /**
       * Use data from the page to make the first call to REST. Finds rows which
       * need qc, inits qc for those rows. If it is not state for MQC it updates
       * the view with current MQC values. If there is an inconsistence between
       * DWH and MQC databases it will stop and show an error message in the
       * page.
       * @param id_run
       * @param lanes
       * @param lanesWithBG
       */
      RunPageMQCControl.prototype.prepareMQC = function (id_run, lanes, lanesWithBG){
        var self = this;
        var jqxhr = $.ajax({
          url: self.REST_SERVICE + id_run,
          cache: false
        }).done(function() {
          var mqc_run_data = jqxhr.responseJSON;
          if(self.isStateForMQC(mqc_run_data)) {
            self.initQC(jqxhr.responseJSON, lanes,
                        function (mqc_run_data, runMQCControl, lanes) {
                          //Show working icons
                          for(var i = 0; i < lanes.length; i++) {
                            lanes[i].children('.lane_mqc_control').each(function(j, obj){
                              $(obj).html("<span class='lane_mqc_working'><img src='/static/images/waiting.gif' title='Processing request.'></span>");
                            });
                          }
                          self.prepareLanes(mqc_run_data, lanes);
                        },
                        function () { //There is no mqc
                          $('.lane_mqc_control').css("padding-right", "0px");
                          $('.lane_mqc_control').css("padding-left", "0px");
                          return;
                        }
            );
          }
        }).fail(function(jqXHR, textStatus, errorThrown) {
          var errorMessage;
          if (jqXHR.responseJSON) {
            errorMessage = jqXHR.responseJSON.error;
          } else {
            errorMessage = errorThrown + " " + textStatus;
          }
          new NPG.QC.UI.MQCErrorMessage(errorMessage).toConsole().display();
        }).always(function(data){
          //Clear progress icon
          $('.lane_mqc_working').empty();
        });
      };

      /**
       * Update values in lanes with values from REST. Then link the lane
       * to a controller. The lane controller will update with widgets or
       * with proper background.
       * @param mqc_run_data
       * @param lanes
       * @returns
       */
      RunPageMQCControl.prototype.prepareLanes = function (mqc_run_data, lanes) {
        if(typeof(mqc_run_data) === "undefined"
            || mqc_run_data == null
            || typeof(lanes) === "undefined"
            || lanes == null) {
          throw new Error("Error: Invalid arguments");
        }
        var result = null;
        var self = this;
        for(var i = 0; i < lanes.length; i++) {
          var cells = lanes[i].children('.lane_mqc_control');
          for(var j = 0; j < cells.length; j++) {
            var obj = $(cells[j]); //Wrap as an jQuery object.
            //Lane from row.
            var position = obj.data('position');
            //Filling previous outcomes
            if('qc_lane_status' in mqc_run_data && position in mqc_run_data.qc_lane_status) {
              //From REST
              var current_status = mqc_run_data.qc_lane_status[position];
              //To html element, LaneControl will render.
              obj.data('initial', current_status);
            }
            //Set up mqc controlers and link them to the individual lanes.
            var c = new NPG.QC.LaneMQCControl(self.abstractConfiguration);
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
      RunPageMQCControl.prototype.laneOutcomesMatch = function (lanesWithBG, mqc_run_data) {
        if(typeof(lanesWithBG) === "undefined"
            || lanesWithBG == null
            || typeof(mqc_run_data) === "undefined"
            || mqc_run_data == null) {
          throw new Error("Error: Invalid arguments");
        }
        var result = {};
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

      return RunPageMQCControl;
    }) ();
    QC.RunPageMQCControl = RunPageMQCControl;

    var RunTitleParseResult = (function () {
      /**
       * Transfer object to deal with title parsing from page (Run + Lane).
       * @memberof module:NPG/QC
       * @constructor
       */
      function RunTitleParseResult(id_run, position, isRunPage) {
        this.id_run    = id_run;
        this.position  = position;
        this.isRunPage = isRunPage;
      }
      return RunTitleParseResult;
    }) ();
    QC.RunTitleParseResult = RunTitleParseResult;

    var RunTitleParser = (function () {
      /**
       * Object to deal with title parsing from page.
       * @memberof module:NPG/QC
       * @constructor
       */
      function RunTitleParser() {
        this.reId = /^NPG SeqQC v[\w\.]+: Results (for run ([0-9]+) \(current run status:|\(all\) for runs ([0-9]+) lanes ([0-9]+)$)/;
      }

      /**
       * Parses the id_run from the title (or text) passed as param.
       * It looks for first integer using a regexp.
       *
       * "^NPG SeqQC v[\w\.]+: Results (for run ([0-9]+) \(current run status:|\(all\) for runs ([0-9]+) lanes ([0-9]+)$)"
       *
       * @param text {String} Text to parse.
       *
       * @returns A RunTitleParseResult object on successful parsing with the
       * regular expression.
       */
      RunTitleParser.prototype.parseIdRun = function (text) {
        if(typeof(text) === "undefined" || text == null) {
          throw new Error("Error: Invalid arguments.");
        }
        var result = null;
        var match = this.reId.exec(text);
        //There is a result from parsing
        if (match != null) {
          //The result of parse looks like a parse
          // and has correct number of elements
          if(match.constructor === Array && match.length > 2) {
            if (match[1].indexOf('for run') === 0) {
              var isRunPage = true;
              var id_run = match[2];
              result = new NPG.QC.RunTitleParseResult(id_run, null, isRunPage);
            } else if (match[1].indexOf('(all) for') === 0) {
              var isRunPage = false;
              var id_run    = match[3];
              var position  = match[4];
              result = new NPG.QC.RunTitleParseResult(id_run, position, isRunPage);
            }
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
