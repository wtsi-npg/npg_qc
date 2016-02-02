/* globals document: false, $: false, define: false, window: false, NPG: false */
'use strict';
define(['jquery'], function () {
  var _classNames = 'qc_outcome_accepted_final qc_outcome_accepted_preliminary qc_outcome_rejected_final qc_outcome_rejected_preliminary qc_outcome_undecided qc_outcome_undecided_final'.split(' ');

  var _classNameForOutcome = function (qcOutcome) {
    var mqcOutcome = typeof qcOutcome !== 'undefined' && typeof qcOutcome.mqc_outcome !== 'undefined' ? qcOutcome.mqc_outcome : '';
    var newClass = 'qc_outcome_' + mqcOutcome.toLowerCase();
    newClass = newClass.replace(/ /g, '_');
    if (_classNames.indexOf(newClass) !== -1) {
      return newClass;
    } else {
      throw 'Unexpected outcome description ' + qcOutcome.mqc_outcome;
    }
  };

  var _processOutcomes = function (outcomes, elementClass) {
    var rpt_keys = Object.keys(outcomes);

    for (var i = 0; i < rpt_keys.length; i++) {
      var rpt_key = rpt_keys[i];
      var qc_outcome = outcomes[rpt_key];
      var new_class = _classNameForOutcome(qc_outcome) ;
      var rptKeyAsSelector;
      if(elementClass === 'lane') {
        rptKeyAsSelector = 'tr[id*="rpt_key:' + rpt_key + '"]';
      } else if (elementClass === 'tag_info') {
        //jQuery can handle ':' as part of a DOM id but needs to be escaped as '\\3A '
        rptKeyAsSelector = '#rpt_key\\3A ' + rpt_key.replace(/:/g, '\\3A ');
      } else {
        throw 'Invalid type of rpt key element class ' + elementClass;
      }
      rptKeyAsSelector = rptKeyAsSelector + ' td.' + elementClass;
      $(rptKeyAsSelector).addClass(new_class);
    }
  };

  var parseRptKeys = function (idTable) {
    var rptKeys = [];
    var idPrefix = 'rpt_key:';
    $('#' + idTable + ' tr').each(function (i, obj) {
      var $obj = $(obj);
      var id = $obj.attr('id');
      if( typeof(id) !== 'undefined' && id !== null && id.lastIndexOf(idPrefix) === 0 ) {
        var rptKey = id.substring(idPrefix.length);
        if( typeof(rptKey) !== 'undefined' && $.inArray(rptKey, rptKeys) === -1 ) {
          rptKeys.push(rptKey);
        }
      }
    });
    return rptKeys;
  };

  var updateDisplayQCOutcomes = function (outcomesData) {
    _processOutcomes(outcomesData.lib, 'tag_info');
    _processOutcomes(outcomesData.seq, 'lane');
  };

  var buildQuery = function (rptKeys) {
    var data = { };
    for( var i = 0; i < rptKeys.length; i++ ) {
      data[rptKeys[i]] = {};
    }
    return data;
  };

  var fetchMQCOutcomes = function (rptKeys, outcomesURL, callOnSuccess) {
    var data = buildQuery(rptKeys);

    $.ajax({
      url: outcomesURL,
      type: 'POST',
      contentType: 'application/json',
      data: JSON.stringify(data),
      cache: false
    }).error(function(jqXHR, textStatus, errorThrown) {
      window.console.log( jqXHR.responseJSON );
      throw "Error while fetching QC outcomes.";
    }).success(function (data, textStatus, jqXHR) {
      try {
        updateDisplayQCOutcomes(data);
        callOnSuccess();
      } catch (er) {
        throw er;
      }
    });
  };

  var processQC = function (tableID, qcOutcomesURL, callbackAfterUpdateView) {
    try {
      var rptKeys = parseRptKeys(tableID);
      fetchMQCOutcomes(rptKeys, qcOutcomesURL, callbackAfterUpdateView);
    } catch (er) {
      window.console.log(er);
    }
  };

  return {
    fetchMQCOutcomes : fetchMQCOutcomes,
    buildQuery: buildQuery,
    updateDisplayQCOutcomes: updateDisplayQCOutcomes,
    parseRptKeys: parseRptKeys,
    processQC: processQC,
  };
});
