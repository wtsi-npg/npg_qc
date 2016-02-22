/* globals $: false, define: false */
'use strict';
define(['jquery'], function (jQuery) {
  var buildUpdateQuery = function (type, qcOutcomes, query) {
    query = query || {};
    query[type] = {};
    for ( var i = 0; i < qcOutcomes.length; i++ ) {
      query[type][qcOutcomes[i].rptKey] = { mqc_outcome: qcOutcomes[i].mqc_outcome };
    }
    query.Action = 'UDPATE';
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
