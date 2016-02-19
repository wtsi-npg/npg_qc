/*
* Copyright (C) 2015 Genome Research Ltd.
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
var NPG;
/**
 * @module NPG
 */
(function (NPG) {
  /**
   * @module NPG/QC
   */
  (function (QC) {
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
        };

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

      var MQCErrorMessage = (function() {
        MQCErrorMessage = function (errorText, placeholder) {
          this.errorText = errorText;
          this.EXCEPTION_STRING_SPLIT = '. at /';
          this.placeholder = placeholder || 'ajax_status';
        }

        MQCErrorMessage.prototype.formatForDisplay = function () {
          var cleanText = this.errorText;
          var n = cleanText.indexOf(this.EXCEPTION_STRING_SPLIT);
          if (n != -1) {
            cleanText = cleanText.substring(0, n + 1);
          }
          return cleanText;
        };

        MQCErrorMessage.prototype.display = function() {
          var cleanText = this.formatForDisplay(this.errorText);
          $("#" + this.placeholder).append("<li class='failed_mqc'>"
              + cleanText
              + '</li>');
          return this;
        };

        MQCErrorMessage.prototype.toConsole = function () {
          window.console && console.log(this.errorText);
          return this;
        };

        return MQCErrorMessage;
      })();
      UI.MQCErrorMessage = MQCErrorMessage;

      var MQCInfoMessage = (function (){

        /**
         * Class for sending info messages to UI interface. By default it places
         * the info message in the same container as the error messages. Uses a
         * different colour to make a difference. The placeholder can also be
         * configured at construction time.
         * @param {String} infoText - Text of the message.
         * @param {String} placeholder - Class of the DOM element where this
         * message will be displayed.
         */
        MQCInfoMessage = function(infoText, placeholder) {
          this.errorText = infoText;
          this.placeholder = placeholder || 'ajax_status';
        }

        MQCInfoMessage.prototype = new NPG.QC.UI.MQCErrorMessage();

        /**
         * Displays the message in the placeholder. Uses bold black typeface.
         */
        MQCInfoMessage.prototype.display = function() {
          var cleanText = this.formatForDisplay(this.errorText);
          $("#" + this.placeholder).append("<li class='info_mqc'>"
              + cleanText
              + '</li>');
          return this;
        };

        return MQCInfoMessage;
      }) ();
      UI.MQCInfoMessage = MQCInfoMessage;

      var MQCLibraryOverallControls = (function () {
        MQCLibraryOverallControls = function() {
          this.PLACEHOLDER_CLASS = 'library_mqc_overall_controls';

          this.CLASS_ALL_ACCEPT    = 'lane_mqc_accept_all';
          this.CLASS_ALL_REJECT    = 'lane_mqc_reject_all';
          this.CLASS_ALL_UNDECIDED = 'lane_mqc_undecided_all';
          //Title for the individual controls
          this.TITLE_ACCEPT    = 'Set all libraries in page as accepted';
          this.TITLE_REJECT    = 'Set all libraries in page as rejected';
          this.TITLE_UNDECIDED = 'Set all libraries in page as undecided';

          this.ICON_ACCEPT    = "<img src='/static/images/tick.png' width='10' height='10'/>";
          this.ICON_REJECT    = "<img src='/static/images/cross.png' width='10' height='10'/>";
          this.ICON_UNDECIDED = "<img src='/static/images/circle.png' width='10' height='10'/>";
        }

        MQCLibraryOverallControls.prototype.setupControls = function (placeholder) {
          placeholder = placeholder || $($('.' + this.PLACEHOLDER_CLASS));
          //Remove the lane placeholder which will not be used in library manuql QC
          placeholder.parent().children('.lane_mqc_control').remove();
          var accept = this.buildControl(this.CLASS_ALL_ACCEPT, this.TITLE_ACCEPT, this.ICON_ACCEPT);
          var und    = this.buildControl(this.CLASS_ALL_UNDECIDED, this.TITLE_UNDECIDED, this.ICON_UNDECIDED);
          var reject = this.buildControl(this.CLASS_ALL_REJECT, this.TITLE_REJECT, this.ICON_REJECT);
          placeholder.html(accept + und + reject);
        };

        MQCLibraryOverallControls.prototype.buildControl = function (cssClass, title, representation) {
          var html = "<span class='lane_mqc_button lane_mqc_overall " + cssClass
                     + "' title='" + title
                     + "' hidden>" + representation
                     + "</span>";
          return html;
        };

        MQCLibraryOverallControls.prototype.init = function (lanes) { //TODO refactor
          var all_accept = $($('.lane_mqc_accept_all').first());
          var all_reject = $($('.lane_mqc_reject_all').first());
          var all_und = $($('.lane_mqc_undecided_all').first());

          all_accept.off("click").on("click", function () {
            var new_outcome;
            for (var i = 0; i < lanes.length; i++) {
              var obj = $(lanes[i].children('.lane_mqc_control').first());
              var controller = obj.data('gui_controller');
              controller.updateOutcome(controller.CONFIG_ACCEPTED_PRELIMINARY);
              new_outcome = new_outcome || controller.CONFIG_ACCEPTED_PRELIMINARY;
            }
            $('input:radio').val([new_outcome]);
          });
          all_reject.off("click").on("click", function () {
            var new_outcome;
            for (var i = 0; i < lanes.length; i++) {
              var obj = $(lanes[i].children('.lane_mqc_control').first());
              var controller = obj.data('gui_controller');
              controller.updateOutcome(controller.CONFIG_REJECTED_PRELIMINARY);
              new_outcome = new_outcome || controller.CONFIG_REJECTED_PRELIMINARY;
            }
            $('input:radio').val([new_outcome]);
          });
          all_und.off("click").on("click", function () {
            var new_outcome;
            for (var i = 0; i < lanes.length; i++) {
              var obj = $(lanes[i].children('.lane_mqc_control').first());
              var controller = obj.data('gui_controller');
              controller.updateOutcome(controller.CONFIG_UNDECIDED);
              new_outcome = new_outcome || controller.CONFIG_UNDECIDED;
            }
            $('input:radio').val([new_outcome]);
          });
          all_accept.show();
          all_reject.show();
          all_und.show();
        };

        return MQCLibraryOverallControls;
      }) ();
      UI.MQCLibraryOverallControls = MQCLibraryOverallControls;

      var MQCLibrary4LaneStats = (function() {
        MQCLibrary4LaneStats = function(id_run, position, id) {
          this.id_run = id_run;
          this.position = position;
          this.id = id;
          this.name = 'MQCLibrary4LaneStats';
          this.css_class = 'mqc_library_4_lane_stats';

          this.uiObject = null;
          this.uiAccepted = null;
          this.uiRejected = null;
          this.uiTotal = null;

          this.STATS_VALUE_CLASS     = 'library_4_lane_stats_value';
          this.TOTAL_ACCEPTED_CLASS  = 'library_4_lane_stats_accepted';
          this.TOTAL_REJECTED_CLASS  = 'library_4_lane_stats_rejected';
          this.TOTAL_LIBRARIES_CLASS = 'library_4_lane_stats_total';
        }

        MQCLibrary4LaneStats.prototype.update = function (accepted, total, rejected) {
          var self = this;
          var values = [accepted, total, rejected];
          self.uiObject.children(self.STATS_VALUE_CLASS).each(function (i, obj) {
            obj.text(values.shift());
          });
        };

        MQCLibrary4LaneStats.prototype.asHtml = function () {
          var self = this;
          var accepted = "<span class='" + self.STATS_VALUE_CLASS + " " + self.TOTAL_ACCEPTED_CLASS + "'></span>/";
          var rejected = "<span class='" + self.STATS_VALUE_CLASS + " " + self.TOTAL_REJECTED_CLASS + "'></span>/";
          var total_libraries = "<span class='" + self.STATS_VALUE_CLASS + " " + self.TOTAL_LIBRARIES_CLASS + "'></span>";
          var html = "<div class='" + self.css_class + "' id=" + self.id + ">"
                      + accepted
                      + total_libraries
                      + rejected
                      + "</div>";

          return html;
        };

        MQCLibrary4LaneStats.prototype.asObject = function () {
          var self = this;
          var obj = $(self.asHtml());
          self.uiObject = obj;
          self.uiAccepted = $(obj.children(self.TOTAL_ACCEPTED_CLASS).first());
          self.uiRejected = $(obj.children(self.TOTAL_REJECTED_CLASS).first());
          self.uiTotal    = $(obj.children(self.TOTAL_LIBRARIES_CLASS).first());

          obj.data('npg_controller', self);
          return obj;
        };
        return MQCLibrary4LaneStats;
      })();
      UI.MQCLibrary4LaneStats = MQCLibrary4LaneStats;
    })(NPG.QC.UI || (NPG.QC.UI = {}));
    var UI = NPG.QC.UI;
  }) (NPG.QC || (NPG.QC = {}));
  var QC = NPG.QC;
}) (NPG || (NPG = {}));
