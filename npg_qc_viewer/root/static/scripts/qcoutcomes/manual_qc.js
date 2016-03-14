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
* Dependencies: jQuery, qc_css_styles, manual_qc_ui
*
*/
/* globals $: false, define: false */
"use strict";
define([
  'jquery',
  './qc_css_styles',
  './qc_outcomes_view',
  './qc_utils',
  './manual_qc_ui'
], function (
  jquery,
  qc_css_styles,
  qc_outcomes_view,
  qc_utils,
  NPG
) {
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
      function ProdConfiguration (qcOutcomesURL) {
        this.qcOutcomesURL = qcOutcomesURL;
      }

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

    QC.launchManualQCProcesses = function (isRunPage, qcOutcomes, qcOutcomesURL) {
      try {
        if ( typeof isRunPage !== 'boolean' ||
             typeof qcOutcomes !== 'object' ||
             typeof qcOutcomesURL !== 'string' ) {
          throw 'Invalid parameter type.';
        }

        if ( typeof qcOutcomes.seq === 'undefined' ) {
          throw 'Sequencing outcomes cannot be undefined.';
        }
        var prodConfiguration = new NPG.QC.ProdConfiguration(qcOutcomesURL);
        var updateOverall;
        var prevOutcomes;

        if ( isRunPage ) {
          prevOutcomes = qcOutcomes.seq;
        } else {
          if ( typeof qcOutcomes.lib === 'undefined' ) {
            throw 'Library outcomes cannot be undefined.';
          }
          prevOutcomes = qcOutcomes.lib;
          // Cut process if lane is already final or there is nothing to qc
          if ( !qc_utils.seqFinal(qcOutcomes.seq) || $('.lane_mqc_control').length === 0 ) {
            return;
          }

          $("#results_summary .lane").first()
                                     .append('<span class="library_mqc_overall_controls"></span>');
          var overallControls = new NPG.QC.UI.MQCLibraryOverallControls(prodConfiguration);
          $('.lane').each(function (index, element){
            var $element = $(element);
            $element.css('background-color', '');
            qc_css_styles.removePreviousQCOutcomeStyles($element);
          });
          overallControls.setupControls();
          overallControls.init();
          updateOverall = $($('.library_mqc_overall_controls')).data('updateIfAllMatch');
        }

        $("<div id='about_qc'><ul><li><a href='/checks/about_qc_proc'>Help for Manual QC</a></li></ul></div>").insertAfter('#links > ul:nth-child(2)');

        $('.lane_mqc_control').each(function (index, element) {
          var $element = $(element);
          var rowId = $element.closest('tr').attr('id');
          if ( typeof rowId === 'string' ) {
            var rptKey = qc_utils.rptKeyFromId(rowId);
            var outcome = typeof prevOutcomes[rptKey] !== 'undefined' ? prevOutcomes[rptKey].mqc_outcome
                                                                      : undefined;
            if ( outcome !== qc_utils.OUTCOMES.ACCEPTED_FINAL &&
                 outcome !== qc_utils.OUTCOMES.REJECTED_FINAL ) {
              var c = isRunPage ? new NPG.QC.LaneMQCControl(prodConfiguration)
                                : new NPG.QC.LibraryMQCControl(prodConfiguration);
              c.rowId   = rowId;
              c.rptKey  = rptKey;
              c.outcome = outcome;
              $element.closest('tr')
                      .find('.lane, .tag_info')
                      .css("background-color", "")
                      .each(function (index, element) {
                        qc_css_styles.removePreviousQCOutcomeStyles($(element));
                      });
              $element.css("padding-right", "5px").css("padding-left", "10px");
              var obj = $(qc_utils.buildIdSelector(c.rowId)).find('.lane_mqc_control');
              c.linkControl(obj);
            }
          }
        });

        if ( typeof updateOverall === 'function' ) {
          updateOverall();
        }
      } catch (ex) {
        qc_utils.displayError('Error while initiating manual QC interface. ' + ex);
      }
    };

    var MQCControl = (function () {
      function MQCControl(abstractConfiguration) {
        this.outcome               = undefined;
        this.rowId                 = undefined;
        this.rptKey                = undefined;
        this.lane_control          = null;  // Container linked to this controller
        this.abstractConfiguration = abstractConfiguration;

        this.TYPE_LIB = 'lib';
        this.TYPE_SEQ = 'seq';

        this.CONFIG_CONTROL_TAG     = 'gui_controller'; //For link in DOM

        //container names
        this.LANE_MQC_WORKING       = 'lane_mqc_working';
        this.LANE_MQC_WORKING_CLASS = '.' + this.LANE_MQC_WORKING;

        this.LANE_MQC_CONTROL       = 'lane_mqc_control';
        this.LANE_MQC_CONTROL_CLASS = '.' + this.LANE_MQC_CONTROL;
      }

      /**
       * Checks the current outcome associated with this controller. If it is not final it will make it final
       * will update the value in the model with an async call and update the view.
       */
      MQCControl.prototype.saveAsFinalOutcome = function() {
        if(this.outcome === qc_utils.OUTCOMES.UNDECIDED) {
          throw new Error('Error: Invalid state');
        }
        if(this.outcome === qc_utils.OUTCOMES.ACCEPTED_PRELIMINARY) {
          this.updateOutcome(qc_utils.OUTCOMES.ACCEPTED_FINAL);
        }
        if(this.outcome === qc_utils.OUTCOMES.REJECTED_PRELIMINARY) {
          this.updateOutcome(qc_utils.OUTCOMES.REJECTED_FINAL);
        }
      };

      /**
       * Methods to deal with background colours.
       */
      MQCControl.prototype.removeAllQCOutcomeCSSClasses = function () {
        var parent = this.lane_control.parent().first();
        qc_css_styles.removePreviousQCOutcomeStyles(parent);
        parent.css("background-color", "");
      };

      MQCControl.prototype.setAcceptedBG = function() {
        this.removeAllQCOutcomeCSSClasses();
        qc_css_styles.displayElementAs(this.lane_control.parent().first(), qc_utils.OUTCOMES.ACCEPTED_FINAL);
      };

      MQCControl.prototype.setRejectedBG = function () {
        this.removeAllQCOutcomeCSSClasses();
        qc_css_styles.displayElementAs(this.lane_control.parent().first(), qc_utils.OUTCOMES.REJECTED_FINAL);
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
        this.outcome = qc_utils.OUTCOMES.ACCEPTED_PRELIMINARY;
        this.removeAllQCOutcomeCSSClasses();
        this.lane_control.parent().css("background-color", "#E5F2FF");
        this.lane_control.children('.lane_mqc_save').show();
      };

      MQCControl.prototype.setRejectedPre = function() {
        this.outcome = qc_utils.OUTCOMES.REJECTED_PRELIMINARY;
        this.removeAllQCOutcomeCSSClasses();
        this.lane_control.parent().css("background-color", "#FFDDDD");
        this.lane_control.children('.lane_mqc_save').show();
      };

      MQCControl.prototype.setAcceptedFinal = function() {
        this.outcome = qc_utils.OUTCOMES.ACCEPTED_FINAL;
        this.lane_control.empty();
        this.removeMQCFormat();
        this.setAcceptedBG();
      };

      MQCControl.prototype.setRejectedFinal = function() {
        this.outcome = qc_utils.OUTCOMES.REJECTED_FINAL;
        this.lane_control.empty();
        this.removeMQCFormat();
        this.setRejectedBG();
      };

      MQCControl.prototype.setUndecided = function() {
        this.outcome = qc_utils.OUTCOMES.UNDECIDED;
        this.removeAllQCOutcomeCSSClasses();
        this.lane_control.children('.lane_mqc_save').hide();
      };

      MQCControl.prototype.setUndefined = function() {
        this.removeAllQCOutcomeCSSClasses();
        this.lane_control.children('.lane_mqc_save').hide();
      };

      /**
       * Switch the outcome and adjust the view accordingly
       * @param outcome new outcome for the control.
       */
      MQCControl.prototype.updateView = function(outcome) {
        try {
          switch ( outcome ) {
            case qc_utils.OUTCOMES.ACCEPTED_PRELIMINARY : this.setAcceptedPre(); break;
            case qc_utils.OUTCOMES.REJECTED_PRELIMINARY : this.setRejectedPre(); break;
            case qc_utils.OUTCOMES.ACCEPTED_FINAL       : this.setAcceptedFinal(); break;
            case qc_utils.OUTCOMES.REJECTED_FINAL       : this.setRejectedFinal(); break;
            case qc_utils.OUTCOMES.UNDECIDED            : this.setUndecided(); break;
          }
        } catch (ex) {
          qc_utils.displayError('Error while updating interface for outcome "' + outcome + '". ' + ex);
        }
      };

      /**
       * What to do after getting a fail during the json request to update
       * the outcome
       * @param data Data from response
       */
      MQCControl.prototype.processAfterFail = function(jqXHR) {
        var self = this;
        self.lane_control.children('input:radio').val([self.outcome]);
        qc_utils.displayJqXHRError(jqXHR);
        console.log(jqXHR.responseText);
      };

      /**
       * Links the individual object with an mqc controller so it can allow mqc.
       */
      MQCControl.prototype.linkControl = function(lane_control) {
        lane_control.data(this.CONFIG_CONTROL_TAG, this);
        this.lane_control = lane_control;
        if ( typeof this.outcome  === "undefined" ) {
          this.generateActiveControls();
          this.setUndefined();
        } else if ( this.outcome === qc_utils.OUTCOMES.ACCEPTED_PRELIMINARY ||
            this.outcome === qc_utils.OUTCOMES.REJECTED_PRELIMINARY ||
            this.outcome === qc_utils.OUTCOMES.UNDECIDED ) {
          //If previous outcome is preliminar.
          this.generateActiveControls();
          switch ( this.outcome ) {
            case qc_utils.OUTCOMES.ACCEPTED_PRELIMINARY : this.setAcceptedPre(); break;
            case qc_utils.OUTCOMES.REJECTED_PRELIMINARY : this.setRejectedPre(); break;
            case qc_utils.OUTCOMES.UNDECIDED            : this.setUndecided(); break;
          }
        }
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
        this.CONFIG_UPDATE_SERVICE = "";
      }

      LaneMQCControl.prototype = new NPG.QC.MQCControl();

      /**
       * Change the outcome.
       */
      LaneMQCControl.prototype.updateOutcome = function(outcome) {
        var prevOutcome = this.outcome;
        try {
          var self = this;
          if(outcome != self.outcome) {
            //Show progress icon
            self.lane_control.find(self.LANE_MQC_WORKING_CLASS).html("<img src='"
                + this.abstractConfiguration.getRoot()
                + "/images/waiting.gif' width='10' height='10' title='Processing request.'>");

            var query = qc_utils.buildUpdateQuery(self.TYPE_SEQ, [{rptKey: self.rptKey, mqc_outcome: outcome}]);
            $.ajax({
              url: self.abstractConfiguration.qcOutcomesURL,
              type: 'POST',
              contentType: 'application/json',
              data: JSON.stringify(query),
              cache: false
            }).error( function (jqXHR) {
              self.processAfterFail(jqXHR);
            }).success( function () {
              try {
                qc_utils.removeErrorMessages();
                self.updateView(outcome);
              } catch (ex) {
                qc_utils.displayError('Succesfully updated outcome to "' +
                                      outcome +
                                      '", but error while updating interface. ' +
                                      ex);
              }
            }).always( function () {
              //Clear progress icon
              self.lane_control.find(self.LANE_MQC_WORKING_CLASS).empty();
            });
          }
        } catch (ex) {
          qc_utils.displayError('Error while trying to update outcome to "' + outcome + '". ' + ex);
          this.lane_control.find('input:radio').val([prevOutcome]);
          this.updateView(prevOutcome);
          this.lane_control.find(self.LANE_MQC_WORKING_CLASS).empty();
        }
      };

      /**
       * Builds the gui controls necessary for the mqc operation and passes them to the view.
       */
      LaneMQCControl.prototype.generateActiveControls = function() {
        var self = this;
        var outcomes = [
          qc_utils.OUTCOMES.ACCEPTED_PRELIMINARY,
          qc_utils.OUTCOMES.UNDECIDED,
          qc_utils.OUTCOMES.REJECTED_PRELIMINARY
        ];
        var root   = self.abstractConfiguration.getRoot();
        var labels = [
          "<img src='" + root + "/images/tick.png'  title='Mark lane as preliminary pass'/>", // for accepted
          '&nbsp;&nbsp;&nbsp;', // for undecided
          "<img src='" + root + "/images/cross.png' title='Mark lane as preliminary fail'/>"
        ]; // for rejected
        //Remove old working span
        self.lane_control.children(self.LANE_MQC_WORKING_CLASS).remove();
        //Create and add radios
        var name = 'radios_' + self.rowId;
        for(var i = 0; i < outcomes.length; i++) {
          var outcome = outcomes[i];
          var label = labels[i];
          var checked = null;
          if (self.outcome === outcome) {
            checked = true;
          }
          var radio = new NPG.QC.UI.MQCOutcomeRadio(self.rowId, outcome, label, name, checked);
          self.lane_control.append(radio.asObject());
        }
        self.addMQCFormat();
        self.lane_control.append($("<span class='lane_mqc_button lane_mqc_save' title='Save current outcome as final (cannot be changed again)'><img src='" +
            self.abstractConfiguration.getRoot() +
            "/images/padlock.png'></span>"));
        self.lane_control.children('.lane_mqc_save').off("click").on("click", function() {
          try {
            self.saveAsFinalOutcome();
          } catch (ex) {
            qc_utils.displayError('Error while saving outcome "' + self.outcome + '" as final. ' + ex);
          }
        });
        if (self.outcome === qc_utils.OUTCOMES.UNDECIDED) {
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
        this.CONFIG_UPDATE_SERVICE = "";
      }

      LibraryMQCControl.prototype = new NPG.QC.MQCControl();

      /**
       * Change the outcome.
       */
      LibraryMQCControl.prototype.updateOutcome = function(outcome) {
        var prevOutcome = this.outcome;
        try {
          var self = this;
          if(outcome != self.outcome) {
            var query = qc_utils.buildUpdateQuery(self.TYPE_LIB, [{rptKey: self.rptKey, mqc_outcome: outcome}]);
            //Show progress icon
            self.lane_control.find(self.LANE_MQC_WORKING_CLASS).html("<img src='" +
                this.abstractConfiguration.getRoot() +
                "/images/waiting.gif' width='10' height='10' title='Processing request.'>");
            //AJAX call.
            $.ajax({
              url: self.abstractConfiguration.qcOutcomesURL,
              type: 'POST',
              contentType: 'application/json',
              data: JSON.stringify(query),
              cache: false
            }).error( function(jqXHR) {
              self.processAfterFail(jqXHR);
            }).success( function () {
              try {
                qc_utils.removeErrorMessages();
                self.updateView(outcome);
                //Update overall controls if needed
                var updateIfAllMatch = $($('.library_mqc_overall_controls')).data('updateIfAllMatch');
                updateIfAllMatch();
              } catch (ex) {
                qc_utils.displayError('Succesfully updated outcome to "' +
                                      outcome +
                                      '", but error while updating interface. ' +
                                      ex);
              }
            }).always( function () {
              //Clear progress icon
              self.lane_control.find(self.LANE_MQC_WORKING_CLASS).empty();
            });
          }
        } catch (ex) {
          qc_utils.displayError('Error while trying to update outcome to "' + outcome + '". ' + ex);
          this.lane_control.find('input:radio').val([prevOutcome]);
          this.updateView(prevOutcome);
          this.lane_control.find(self.LANE_MQC_WORKING_CLASS).empty();
        }
      };

      /**
       * Builds the gui controls necessary for the mqc operation and passes them
       * to the view.
       */
      LibraryMQCControl.prototype.generateActiveControls = function() {
        var self     = this;
        var outcomes = [
          qc_utils.OUTCOMES.ACCEPTED_PRELIMINARY,
          qc_utils.OUTCOMES.UNDECIDED,
          qc_utils.OUTCOMES.REJECTED_PRELIMINARY
        ];
        var root   = self.abstractConfiguration.getRoot();
        var labels = [
          "<img src='" + root + "/images/tick.png'  title='Mark lane as preliminary pass'/>", // for accepted
          '&nbsp;&nbsp;&nbsp;', // for undecided
          "<img src='" + root + "/images/cross.png' title='Mark lane as preliminary fail'/>" // for rejected
        ];
        //Remove old working span
        self.lane_control.children(self.LANE_MQC_WORKING_CLASS).remove();
        var name = 'radios_' + self.rowId;
        for(var i = 0; i < outcomes.length; i++) {
          var outcome = outcomes[i];
          var label = labels[i];
          var checked = ( self.outcome === outcome ) ? true : null;
          var radio = new NPG.QC.UI.MQCOutcomeRadio(self.rowId, outcome, label, name, checked);
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

      return LibraryMQCControl;
    }) ();
    QC.LibraryMQCControl = LibraryMQCControl;
    /* Plex */
  }) (NPG.QC || (NPG.QC = {}));
}) (NPG || (NPG = {}));

return NPG;
});

