'use strict';
define(['jquery'], function ($) {

  var _classNameForOutcome = function (qc_outcome) {
    var new_class = '';
    if( qc_outcome.mqc_outcome === 'Accepted final' ) {
      new_class = 'passed';
    }
    return new_class;
  };

  var _processOutcomes = function (outcomes, rowClass) {
    var rpt_keys = Object.keys(outcomes);

    for (var i = 0; i < rpt_keys.length; i++) {
      var rpt_key = rpt_keys[i];
      var qc_outcome = outcomes[rpt_key];

      var new_class = _classNameForOutcome(qc_outcome) ;
      $("." + rowClass + "[data-rpt_key='" + rpt_key + "']").addClass(new_class);
    }
  };

  var fetchQCOutcomes = function () {
    var data = { };
    $('.lane').each(function (i, obj) {
      var $obj = $(obj);
      data[$obj.data('rpt_key')] = {};
    });

    $.ajax({
      url: "/qcoutcomes",
      type: 'POST',
      contentType: 'application/json',
      data: JSON.stringify(data)
    }).error(function(jqXHR, textStatus, errorThrown) {
      window.console.log( jqXHR.responseJSON );
    }).success(function (data, textStatus, jqXHR) {
      _processOutcomes(data.lib, 'tag_info');
      _processOutcomes(data.seq, 'lane');
    });
  };

  return {
    fetchQCOutcomes : fetchQCOutcomes,
  };
});
