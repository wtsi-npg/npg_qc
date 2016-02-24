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
define([
  'jquery',
  './qc_utils'
], function (
  jquery,
  qc_utils
) {
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
          qc_utils.removeErrorMessages();
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

        MQCLibraryOverallControls.prototype.init = function () { //TODO refactor
          var all_accept = $($('.lane_mqc_accept_all').first());
          var all_reject = $($('.lane_mqc_reject_all').first());
          var all_und = $($('.lane_mqc_undecided_all').first());

          var update = function (query, callback) {
            $.ajax({
              url: '/qcoutcomes',
              type: 'POST',
              contentType: 'application/json',
              data: JSON.stringify(query),
              cache: false
            }).error(function(jqXHR) {
              var errorMessage;
              if ( typeof jqXHR.responseJSON === 'object' && typeof jqXHR.responseJSON.error === 'string') {
                errorMessage = $.trim(jqXHR.responseJSON.error);
              } else {
                errorMessage = ( jqXHR.status || '' ) + ' ' + ( jqXHR.statusText || '' );
                console.log(jqXHR.responseText);
              }
              new NPG.QC.UI.MQCErrorMessage(errorMessage).toConsole().display();
            }).success(function (data) {
              qc_utils.removeErrorMessages();
              callback();
            }).always(function(){
            });
          };

          all_accept.off("click").on("click", function () {
            var ids = [];
            $('.lane_mqc_control').closest('tr').each(function (index, element) {
              ids.push({rptKey: qc_utils.rptKeyFromId($(element).attr('id')), mqc_outcome: 'Accepted preliminary'});
            });
            var query = qc_utils.buildUpdateQuery('lib', ids);
            var callback = function () {
              var new_outcome;
              $('.lane_mqc_control').each( function (index, element) {
                $element = $(element);
                var controller = $element.data('gui_controller');
                controller.updateView(controller.CONFIG_ACCEPTED_PRELIMINARY);
                new_outcome = new_outcome || controller.CONFIG_ACCEPTED_PRELIMINARY;
              });
              $('input:radio').val([new_outcome]);
            };
            update(query, callback);
          });
          all_reject.off("click").on("click", function () {
            var ids = [];
            $('.lane_mqc_control').closest('tr').each(function (index, element) {
              ids.push({rptKey: qc_utils.rptKeyFromId($(element).attr('id')), mqc_outcome: 'Rejected preliminary'});
            });
            var query = qc_utils.buildUpdateQuery('lib', ids);
            var callback = function () {
              var new_outcome;
              $('.lane_mqc_control').each( function (index, element) {
                $element = $(element);
                var controller = $element.data('gui_controller');
                controller.updateView(controller.CONFIG_REJECTED_PRELIMINARY);
                new_outcome = new_outcome || controller.CONFIG_REJECTED_PRELIMINARY;
              });
              $('input:radio').val([new_outcome]);
            }
            update(query, callback);
          });
          all_und.off("click").on("click", function () {
            var ids = [];
            $('.lane_mqc_control').closest('tr').each(function (index, element) {
              ids.push({rptKey: qc_utils.rptKeyFromId($(element).attr('id')), mqc_outcome: 'Undecided'});
            });
            var query = qc_utils.buildUpdateQuery('lib', ids);
            var callback = function () {
              var new_outcome;
              $('.lane_mqc_control').each( function (index, element) {
                $element = $(element);
                var controller = $element.data('gui_controller');
                controller.updateView(controller.CONFIG_UNDECIDED);
                new_outcome = new_outcome || controller.CONFIG_UNDECIDED;
              });
              $('input:radio').val([new_outcome]);
            };
            update(query, callback);
          });
          all_accept.show();
          all_reject.show();
          all_und.show();
        };

        return MQCLibraryOverallControls;
      }) ();
      UI.MQCLibraryOverallControls = MQCLibraryOverallControls;

    })(NPG.QC.UI || (NPG.QC.UI = {}));
    var UI = NPG.QC.UI;
  }) (NPG.QC || (NPG.QC = {}));
  var QC = NPG.QC;
}) (NPG || (NPG = {}));

return NPG;
});

