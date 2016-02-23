/* globals $: false, define: false */
'use strict';
define(['jquery'], function (jQuery) {
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

  var buildIdSelector = function (id) {
    return '#' + id.replace(/:/g, '\\3A ');
  };

  return {
    buildUpdateQuery: buildUpdateQuery,
    buildIdSelector: buildIdSelector
  };
});
