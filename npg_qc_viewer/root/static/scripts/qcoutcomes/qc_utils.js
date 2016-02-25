/*
 *
 */
/* globals $: false, define: false */
'use strict';
define(['jquery'], function () {
  var ID_PREFIX = 'rpt_key:';
  var ACTION    = 'UPDATE';

  var EXCEPTION_SPLIT = /^(.*?)( at \/)/;

  var buildIdSelector = function (id) {
    return '#' + id.replace(/:/g, '\\3A ');
  };

  var buildIdSelectorFromRPT = function (rptKey) {
    return buildIdSelector(ID_PREFIX + rptKey);
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
    if( id.lastIndexOf(ID_PREFIX) !== 0 ) {
      throw 'Id does not match the expected format';
    }
    return id.substring(ID_PREFIX.length);
  };

  var seqFinal = function (seqOutcomes) {
    var seqKeys = Object.keys(seqOutcomes);
    for ( var i = 0; i < seqKeys.length; i++ ) {
      if ( seqOutcomes[seqKeys[i]].mqc_outcome.indexOf('final') !== -1 ) {
        return false;
      }
    }
    return true;
  };

  return {
    buildIdSelector: buildIdSelector,
    buildUpdateQuery: buildUpdateQuery,
    buildIdSelectorFromRPT: buildIdSelectorFromRPT,
    displayError: displayError,
    displayJqXHRError: displayJqXHRError,
    removeErrorMessages: removeErrorMessages,
    rptKeyFromId: rptKeyFromId,
    seqFinal: seqFinal,
  };
});
