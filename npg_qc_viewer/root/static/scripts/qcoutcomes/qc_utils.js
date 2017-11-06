/*
 *
 */
/* globals $: false, define: false */
'use strict';
define(['jquery'], function () {
  var ID_PREFIX = 'rpt_key:';
  var ACTION    = 'UPDATE';

  var EXCEPTION_SPLIT = /^(.*?)( at \/)/;
  var TEST_FINAL      = /(final)$/i;
  var TEST_LIKE_ID    = /^rpt_key:/;
  var KEY_SEPARATORS   = /\d:\d/g;

  var buildIdSelector = function (id) {
    return '#' + id.replace(/:/g, '\\3A ');
  };

  var buildIdSelectorFromRPT = function (rptKey) {
    return buildIdSelector(ID_PREFIX + rptKey);
  };

  var buildQuery = function (rptKeys) {
    var data = { };
    for( var i = 0; i < rptKeys.length; i++ ) {
      data[rptKeys[i]] = {};
    }
    return data;
  };

  var buildUpdateQuery = function (type, qcOutcomes, query) {
    query = query || {};
    query[type] = {};
    for ( var i = 0; i < qcOutcomes.length; i++ ) {
      query[type][qcOutcomes[i].rptKey] = { mqc_outcome: qcOutcomes[i].mqc_outcome };
    }
    query.Action = ACTION;
    return query;
  };

  var removeErrorMessages = function () {
    $("#ajax_status").empty();
  };

  var displayError = function( er ) {
    var message;
    if( typeof er === 'string' ) {
      message = er;
    } else {
      message = '' + er;
    }
    removeErrorMessages();
    $('#ajax_status').empty().append("<li class='failed_mqc'>" + message + '</li>');
  };

  //This method takes an rpt_key and returns a boolean evaluating wether the key defines 
  //a lane (true) or a plex (false)
  var isLaneKey = function (rpt_key) {
    if ( typeof rpt_key == 'undefined' || typeof rpt_key !== 'string' ) {
      throw 'Invalid argument';
    }
    var count = [], found;
    while (found = KEY_SEPARATORS.exec(rpt_key)) {
      count.push(found[0]);
      KEY_SEPARATORS.lastIndex -= found[0].split(':')[1].length;
    }
    if (count.length === 1){
      return true;  
    } else if (count.length === 2){
      return false
    } else {
      throw 'Invalid key format'
    } 
  };

  var displayJqXHRError = function ( jqXHR ) {
    if ( typeof jqXHR == null || typeof jqXHR !== 'object' ) {
      throw 'Invalid parameter';
    }
    var message;
    if ( typeof jqXHR.responseJSON != null &&
         typeof jqXHR.responseJSON === 'object' &&
         typeof jqXHR.responseJSON.error === 'string' ) {
      message = $.trim(jqXHR.responseJSON.error);
      var textMatch = EXCEPTION_SPLIT.exec(message);
      if ( textMatch != null && textMatch.length > 1 ) {
        message = textMatch[1];
      }
    } else  {
      message = ( jqXHR.status || '' ) + ' ' + ( jqXHR.statusText || '');
    }
    displayError(message);
  };

  var rptKeyFromId = function (id) {
    if ( typeof id !== 'string' ) {
      throw 'Invalid arguments';
    }
    if ( TEST_LIKE_ID.exec(id) == null ) {
      throw 'Id does not match the expected format.';
    }
    return id.substring(ID_PREFIX.length);
  };

  var seqFinal = function (seqOutcomes) {
    var seqKeys = Object.keys(seqOutcomes);
    for ( var i = 0; i < seqKeys.length; i++ ) {
      if ( TEST_FINAL.exec(seqOutcomes[seqKeys[i]].mqc_outcome) != null ) {
        return false;
      }
    }
    return true;
  };
  
  var QC_OUTCOMES = {
    ACCEPTED_PRELIMINARY: 'Accepted preliminary',
    ACCEPTED_FINAL:       'Accepted final',
    REJECTED_PRELIMINARY: 'Rejected preliminary',
    REJECTED_FINAL:       'Rejected final',
    UNDECIDED:            'Undecided',
    UNDECIDED_FINAL:      'Undecided final'
  };

  return {
    buildIdSelector: buildIdSelector,
    buildQuery: buildQuery,
    buildUpdateQuery: buildUpdateQuery,
    buildIdSelectorFromRPT: buildIdSelectorFromRPT,
    displayError: displayError,
    displayJqXHRError: displayJqXHRError,
    removeErrorMessages: removeErrorMessages,
    isLaneKey: isLaneKey,
    rptKeyFromId: rptKeyFromId,
    seqFinal: seqFinal,
    OUTCOMES: QC_OUTCOMES
  };
});
