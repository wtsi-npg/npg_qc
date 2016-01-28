'use strict';
define(['jquery'], function ($) {
  var _classNameForOutcome = function (qc_outcome) {
    var new_class = '';
    if( qc_outcome.mqc_outcome === 'Accepted final' ) {
      new_class = 'passed';
    } else if (qc_outcome.mqc_outcome === 'Rejected final') {
      new_class = 'failed';
    }
    return new_class;
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
      } else {
        rptKeyAsSelector = '#rpt_key\\3A ' + rpt_key.replace(/:/g, '\\3A '); //With : escaped as \\:
      }
      rptKeyAsSelector = rptKeyAsSelector + ' td.' + elementClass;
      $(rptKeyAsSelector).addClass(new_class);
    }
  };

  var parseRptKeys = function (idTable) {
    var rptKeys = [];
    $('#' + idTable + ' tr').each(function (i, obj) {
      var $obj = $(obj);
      if( $obj.attr('id') !== undefined ) {
        var rptKey = $obj.attr('id').substring('rpt_key:'.length);
        if( rptKey !== undefined && $.inArray(rptKey, rptKeys) === -1 ) {
          rptKeys.push(rptKey);
        }
      }
    });
    return rptKeys;
  };

  var showMQCOutcomes = function (rptKeys, outcomesURL) {
    var data = { };
    for( var i = 0; i < rptKeys.length; i++ ) {
      data[rptKeys[i]] = {};
    }

    $.ajax({
      url: outcomesURL,
      type: 'POST',
      contentType: 'application/json',
      data: JSON.stringify(data)
    }).error(function(jqXHR, textStatus, errorThrown) {
      window.console.log( jqXHR.responseJSON );
    }).success(function (data, textStatus, jqXHR) {
      updateQCOutcomes(data);
    });
  };

  var updateQCOutcomes = function (outcomesData) {
    _processOutcomes(outcomesData.lib, 'tag_info');
    _processOutcomes(outcomesData.seq, 'lane');
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
    showMQCOutcomes : showMQCOutcomes,
    setPageForManualQC : setPageForManualQC,
    updateQCOutcomes: updateQCOutcomes,
    parseRptKeys: parseRptKeys,
  };
});
