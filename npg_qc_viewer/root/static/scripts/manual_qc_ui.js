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