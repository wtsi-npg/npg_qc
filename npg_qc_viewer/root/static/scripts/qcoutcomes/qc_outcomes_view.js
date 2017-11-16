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
   *This function adds a clickable link to the page's menu, which on click activates the anotation process  
   *of the end user's utility.
   */
  var addUQCAnnotationLink = function () {
    $("#menu #links > ul:eq(3)").append('<li><a class="uqcClickable">UQC annotation</a></li>');
  };

  /*
   *This function assigns a string defined icon (ie:&#10003) in the .lane column to signal
   *the outcome of the utility flag from a certain tag. If a previous icon exists, it
   *removes it before adding the new one.
   *
   *It requires a DOM object (obj) and a string (utility) describing the utility of the tag lane:
   *Accepted (✓) or Rejected (✘). If the utility is "Undecided" there is no widget
   *to display.
   *
   *
   * Example:
   *
   *  $('.lane').each(function (i, obj) {
   *    mqc_outcomes.utilityDisplaySwitch(obj,"Accepted");
   *  });
   *
   */
  var utilityDisplaySwitch = function (obj, utility) {
    if (!(obj instanceof Element)) {
      throw new TypeError('Parameter obj must be defined and of type (DOM) Element');
    }
    if (typeof utility !== 'string') {
      throw new TypeError('Utility should be a string');
     }
    if ( utility !== 'Accepted' && utility !== 'Rejected' && utility !== 'Undecided') {
      throw 'Invalid value ' + utility;
    }

    var o = $(obj);
    var icon;
    o.children().remove('.utility_pass, .utility_fail');//in case an icon exists
    if (utility === 'Accepted') {
      icon = '<span class="utility_pass">&#10003;</span>';//&#10003=check ✓
    } else if (utility === 'Rejected') {
      icon = '<span class="utility_fail">&#10008;</span>';//&#10008=cross ✘
    }
    o.children('a').after(icon);
  };

  /*
   *This function returns the DOM element(s) corresponding to the JQuery defined by the input:
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
    if (fuzzyMatch) {
      rptKeyAsSelector = 'tr[id*="' + ID_PREFIX + key + '"]';
    } else {
      //jQuery can handle ':' as part of a DOM id's but it needs to be escaped as '\\3A '
      rptKeyAsSelector = '#rpt_key\\3A ' + key.replace(/:/g, '\\3A ');
    }
    return $(rptKeyAsSelector + ' td.' + elementClass);
  };


  /*
  *This function processes the QCoutcomes defined by the input outcomes. It takes as inputs
  *'outcomes' (the particular outcomes themselves -lib,seq or uqc-  for each rpt_key), 
  *'outcomeType' (either mqc or uqc outcome), and the 'elementClass' (which indicates the column 
  *where the widget will be displayed).
  *It returns a hash (existingElements) containing for each rpt_key a boolean indicating
  *wether or not a matching DOM element has been found.
  *
  * Example:
  *
  *  _processOutcomes(outcomesData.seq, 'mqc_outcome', 'lane');
  *
  */
  var _processOutcomes = function (outcomes, outcomeType, elementClass) {
    if ((elementClass !== 'lane') && (elementClass !== 'tag_info')) {
      throw 'Invalid type of rpt key element class ' + elementClass;
    }
    var existingElements = {};
    var rpt_keys = Object.keys(outcomes);
    for (var i in rpt_keys) {
      var rpt_key = rpt_keys[i];
      var qc_outcome = outcomes[rpt_key][outcomeType];
      if (typeof qc_outcome === 'undefined' ) {
        throw 'Malformed QC outcomes data for ' + rpt_key;
      }
      var fuzzyMatch = outcomeType === 'uqc_outcome' ? false : elementClass === 'lane';  
      var selection = _selectionForKey(rpt_key, elementClass, fuzzyMatch);
      // Allows for a mismatch between the received keys and
      // available DOM elements.
      if (typeof selection !== 'undefined' && selection.length > 0) {
        if (outcomeType === 'uqc_outcome') {
          utilityDisplaySwitch(selection[0], qc_outcome);
        } else {
          qc_css_styles.displayElementAs(selection, qc_outcome);
        }
        existingElements[rpt_key]= 1;
      } else {
        existingElements[rpt_key]= 0;
      }
    }
    return existingElements;
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

  /*
  *This function update the display of the QC outcomes defined by the input outcomesData.
  *The function processes 3 types of outcomes : 'lib' and 'seq' (with information from the manual qc) 
  *and 'uqc' (with information from the end user utility qc).
  *For uqc, depending on the key, the widget might go to either lane or tag column, 
  *so we will proces outcomes one a time.
  *
  * Example:
  *
  *  $.ajax({
  *     url: outcomesURL,
  *     type: 'POST',
  *     contentType: 'application/json',
  *     data: JSON.stringify(query),
  *     cache: false
  *   }).success(function (data) {
  *      _updateDisplayWithQCOutcomes(data);
  *   });
  *
  */
  var _updateDisplayWithQCOutcomes = function (outcomesData) {
    _processOutcomes(outcomesData.lib, 'mqc_outcome', 'tag_info');
    _processOutcomes(outcomesData.seq, 'mqc_outcome', 'lane');
    if (outcomesData.uqc !== undefined) {
      var rpt_keys = Object.keys(outcomesData.uqc);
      for (var i in rpt_keys) {
        var key = rpt_keys[i];
        var elementClass = qc_utils.isLaneKey(key) ? 'lane' : 'tag_info';
        var uqcOutcomeforKey = {};
        uqcOutcomeforKey[key] = outcomesData.uqc[key];
        _processOutcomes( uqcOutcomeforKey, 'uqc_outcome', elementClass);
      }
    } 
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
    utilityDisplaySwitch: utilityDisplaySwitch,
    fetchAndProcessQC: fetchAndProcessQC,
    addUQCAnnotationLink: addUQCAnnotationLink
  };
});
