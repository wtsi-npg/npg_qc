/*
 *
 */
/* globals $: false, define: false */
'use strict';
define(['jquery'], function () {
  var ID_PREFIX = 'rpt_key:';
  var ACTION    = 'UPDATE';

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

  var rptKeyFromId = function (id) {
    if ( typeof id !== 'string' ) {
      throw 'Invalid arguments';
    }
    if( id.lastIndexOf(ID_PREFIX) !== 0 ) {
      throw 'Id does not match the expected format';
    }
    return id.substring(ID_PREFIX.length);
  };

  var buildIdSelector = function (id) {
    return '#' + id.replace(/:/g, '\\3A ');
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

  var buildIdSelectorFromRPT = function (rptKey) {
    return buildIdSelector(ID_PREFIX + rptKey);
  };

  return {
    buildUpdateQuery: buildUpdateQuery,
    buildIdSelectorFromRPT: buildIdSelectorFromRPT,
    buildIdSelector: buildIdSelector,
    seqFinal: seqFinal,
    removeErrorMessages: removeErrorMessages,
    rptKeyFromId: rptKeyFromId
  };
});
