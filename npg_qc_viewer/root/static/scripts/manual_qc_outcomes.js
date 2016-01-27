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

  var setPageForManualQC = function() {
    // Getting the run_id from the title of the page using the qc part too.
    var runTitleParserResult = new NPG.QC.RunTitleParser().parseIdRun($(document)
                                                          .find("title")
                                                          .text());
    //If id_run
    if(typeof(runTitleParserResult) != undefined && runTitleParserResult != null) {
      var id_run = runTitleParserResult.id_run;
      var prodConfiguration = new NPG.QC.ProdConfiguration();
      //Read information about lanes from page.
      var lanes = []; //Lanes without previous QC, blank BG
      var control;

      if (runTitleParserResult.isRunPage) {
        var lanesWithBG = []; //Lanes with previous QC, BG with colour
        control = new NPG.QC.RunPageMQCControl(prodConfiguration);
        control.parseLanes(lanes, lanesWithBG);
        control.prepareMQC(id_run, lanes, lanesWithBG);
      } else {
        var position = runTitleParserResult.position;
        control = new NPG.QC.LanePageMQCControl(prodConfiguration);
        control.parseLanes(lanes);
        control.prepareMQC(id_run, position, lanes);
      }
    }
  };

  return {
    fetchQCOutcomes : fetchQCOutcomes,
    setPageForManualQC : setPageForManualQC,
  };
});
