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

      var MQCLibraryOverallControls = (function () {
        MQCLibraryOverallControls = function() {
          this.PLACEHOLDER_CLASS = 'library_mqc_overall_controls';

          this.CLASS_ALL_ACCEPT    = 'lane_mqc_accept_all';
          this.CLASS_ALL_REJECT    = 'lane_mqc_reject_all';
          this.CLASS_ALL_UNDECIDED = 'lane_mqc_undecided_all';
          //Title for the individual controls
          this.TITLE_ACCEPT    = 'Set all as accepted';
          this.TITLE_REJECT    = 'Set all as rejected';
          this.TITLE_UNDECIDED = 'Set all as undecided';

          this.ICON_ACCEPT    = "<img src='/static/images/tick.png'/>";
          this.ICON_REJECT    = "<img src='/static/images/cross.png'/>";
          this.ICON_UNDECIDED = "und";
        }

        MQCLibraryOverallControls.prototype.setupControls = function (placeholder) {
          placeholder = placeholder || $($('.' + this.PLACEHOLDER_CLASS));
          var accept = this.buildControl(this.CLASS_ALL_ACCEPT, this.TITLE_ACCEPT, this.ICON_ACCEPT);
          var und    = this.buildControl(this.CLASS_ALL_UNDECIDED, this.TITLE_UNDECIDED, this.ICON_UNDECIDED);
          var reject = this.buildControl(this.CLASS_ALL_REJECT, this.TITLE_REJECT, this.ICON_REJECT);
          placeholder.html(accept + und + reject);
        };

        MQCLibraryOverallControls.prototype.buildControl = function (cssClass, title, representation) {
          var html = "<span class='" + cssClass
                     + "' title='" + title
                     + "' hidden>" + representation
                     + "</span>";
          return html;
        };

        MQCLibraryOverallControls.prototype.init = function (lanes) {
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