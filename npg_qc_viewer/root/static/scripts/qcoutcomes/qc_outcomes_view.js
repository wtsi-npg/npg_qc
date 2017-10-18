/*
 * Module which provides functionality for fetching and rendering QC outcomes
 * from the npg_qc_viewer qcoutcomes JSON service.
 *
 * The function fetchAndProcessQC wraps the logic for fetching the QC outcomes
 * and rendering them in the current page. It also allows to define a callback
 * function to do post processing e.g. prepare the interface for manual QC.
 *
 * The function requires the DOM id for the summary table and the URL for the
 * JSON service as parameters. The callback for postprocessing is optional.
 *
 * Example:
 *
 *   var postRendering = function() {
 *     doSomethingWithRenderedPage();
 *     andMaybeSomethingElse();
 *   }
 *
 *   qc_outcomes_view.fetchAndProcessQC('summary_table_id',
 *                              'qcoutcomes_json_url',
 *                              postRendering);
 *
 */
/* globals $: false, define: false, Element: false */
'use strict';
define([
  'jquery',
  './qc_css_styles',
  './qc_utils'
], function (
  jQuery,
  qc_css_styles,
  qc_utils
) {
  var ID_PREFIX = 'rpt_key:';

  /*
   *This function assigns a string defined icon (ie:&#10003) in the .lane column to signal
   *the outcome of the usability flag from a certain tag. If a previous icon exists, it
   *removes it before adding the new one.
   *
   *It requires a DOM object (obj) and a boolean flag (usability) displaying wether
   *the usability of the tag lane is switched on (✓) or off (✘).
   *
   *
   * Example:
   *
   *  $('.lane').each(function (i, obj) {
   *    mqc_outcomes.usabilityDisplaySwitch(obj,1);
   *  });
   *
   */
  var usabilityDisplaySwitch = function (obj, usability) {
    if (!(obj instanceof Element)) {
      throw new TypeError('Parameter obj must be defined and of type (DOM) Element');
    }
    if (typeof usability !== 'boolean') {
      throw new TypeError('Usability should be boolean');
    }
    var o = $(obj);
    var icon;
    o.children().remove('.utility_PASS, .utility_FAIL');//in case an icon exists
    if(usability){
      icon = $('<div class="utility_PASS">&#10003;</div>');//&#10003=check ✓
    } else {
      icon = $('<div class="utility_FAIL">&#10008;</div>');//&#10008=cross ✘
    }
    o.append(icon);
  };

  /*
   *This function returns the DOM element corresponding to the JQuery defined by the input:
   *key: the rpt_key, 
   *elementClass: the name of the column, 
   *fuzzyMatch: boolean defining whether the selector returns all plexes associated with a lane key (true)
   *or just the exact match (false).
   *
   * Example:
   *
   *  _selectionForKey("18245:1", 'lane', 1);
   *
   */
  var _selectionForKey = function (key, elementClass, fuzzyMatch) {
    if (!key || !elementClass) {
      throw 'Both key and elementClass are required';
    }
    var rptKeyAsSelector;
    if (fuzzyMatch){
      rptKeyAsSelector = 'tr[id*="' + ID_PREFIX + key + '"]';
    } else {
      //jQuery can handle ':' as part of a DOM id's but it needs to be escaped as '\\3A '
      rptKeyAsSelector = '#rpt_key\\3A ' + key.replace(/:/g, '\\3A ');
    }
    return $(rptKeyAsSelector + ' td.' + elementClass);
  };

  var _processOutcomes = function (outcomes, elementClass) {
    if ((elementClass !== 'lane') && (elementClass !== 'tag_info')) {
      throw 'Invalid type of rpt key element class ' + elementClass;
    }
    var outcomesStatus = {};
    //console.log("1st outcome",outcomes[0]);
    var rpt_keys = Object.keys(outcomes);
    for (var i = 0; i < rpt_keys.length; i++) {
      var rpt_key = rpt_keys[i];
      var qc_outcome = outcomes[rpt_key];
      if (typeof qc_outcome.mqc_outcome === 'undefined') {
        throw 'Malformed QC outcomes data for ' + rpt_key;
      }
      var fuzzy = elementClass === 'lane';
      var selection = _selectionForKey(rpt_key, elementClass, fuzzy);
      var result;
      // Allows for a mismatch between the received keys and
      // available DOM elements.
      if (typeof selection !== 'undefined' && selection.length > 0) {
        qc_css_styles.displayElementAs(selection, qc_outcome.mqc_outcome);
        result = 1;
      } else {
        result = 0;
      }
      outcomesStatus[rpt_key] = result;
    }
    return outcomesStatus;
  };

  var _parseRptKeys = function (idTable) {
    var rptKeys = [];
    $('#' + idTable + ' tr').each(function (i, obj) {
      var $obj = $(obj);
      var id = $obj.attr('id');
      if( typeof id !== 'undefined' && id !== null && id.lastIndexOf(ID_PREFIX) === 0 ) {
        var rptKey = qc_utils.rptKeyFromId(id);
        if ( typeof rptKey !== 'undefined' && $.inArray(rptKey, rptKeys) === -1 ) {
          rptKeys.push(rptKey);
        }
      }
    });
    return rptKeys;
  };

  var _updateDisplayWithQCOutcomes = function (outcomesData) {
    _processOutcomes(outcomesData.lib, 'tag_info');
    _processOutcomes(outcomesData.seq, 'lane');
  };

  var _fetchQCOutcomesUpdateView = function (rptKeys, outcomesURL, callOnSuccess) {
    if ( rptKeys.length > 0 ) {
      $.ajax({
        url: outcomesURL,
        type: 'POST',
        contentType: 'application/json',
        data: JSON.stringify(qc_utils.buildQuery(rptKeys)),
        cache: false
      }).error(function(jqXHR) {
        qc_utils.displayJqXHRError(jqXHR);
      }).success(function (data) {
        try {
          _updateDisplayWithQCOutcomes(data);
          if( typeof callOnSuccess === 'function' ) {
            callOnSuccess(data);
          }
        } catch (er) {
          qc_utils.displayError('Error while displaying current QC outcomes. ' + er);
        }
      });
    }
  };

  var fetchAndProcessQC = function (tableID, qcOutcomesURL, callbackAfterUpdateView) {
    try {
      var rptKeys = _parseRptKeys(tableID);
      _fetchQCOutcomesUpdateView(rptKeys, qcOutcomesURL, callbackAfterUpdateView);
    } catch (er) {
      qc_utils.displayError('Error while fetching current QC outcomes. ' + er);
    }
  };

  return {
    _fetchQCOutcomesUpdateView: _fetchQCOutcomesUpdateView,
    _updateDisplayWithQCOutcomes: _updateDisplayWithQCOutcomes,
    _parseRptKeys: _parseRptKeys,
    _processOutcomes: _processOutcomes,
    _selectionForKey: _selectionForKey,
    usabilityDisplaySwitch: usabilityDisplaySwitch,
    fetchAndProcessQC: fetchAndProcessQC
  };
});
