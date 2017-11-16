/* globals $, requirejs, document */
"use strict";
requirejs.config({
  baseUrl: '/static',
  catchError: true,
  paths: {
    jquery: 'bower_components/jquery/dist/jquery',
    d3: 'bower_components/d3/d3.min',
    unveil: 'bower_components/jquery-unveil/jquery.unveil',
    'table-export': 'bower_components/table-export/tableExport.min',
  },
  shim: {
    d3: {
      //makes d3 available automatically for all modules
      exports: 'd3'
    },
    unveil: ["jquery"],
    'table-export': ["jquery"],
  }
});

requirejs.onError = function (err) {
    if ( console ) {
      console.log(err.requireType);
      console.log('modules: ' + err.requireModules);
    }
    throw err;
};

requirejs([
  'scripts/collapse',
  'scripts/qcoutcomes/qc_outcomes_view',
  'scripts/plots',
  'scripts/format_for_csv',
  'scripts/qcoutcomes/qc_page',
  'scripts/qcoutcomes/manual_qc',
  'scripts/qcoutcomes/qc_utils',
  'unveil',
  'table-export'
], function(
  collapse,
  qc_outcomes_view,
  plots,
  format_for_csv,
  qc_page,
  NPG,
  qc_utils
) {
  var qcp;
  $(document).ready(function(){
    //Setup for heatmaps to load on demand.
    $("img").unveil(2000);
    collapse.init(function() {

      // We scroll after collapse toggles to fire modify on view to generate plots
      window.scrollBy(0,1); window.scrollBy(0,-1);
    });
    qcp = qc_page.pageForQC();
    var callAfterGettingOutcomes = null;
    if (qcp.isPageForMQC){
      callAfterGettingOutcomes = function (data) {
        NPG.QC.launchManualQCProcesses(qcp.isRunPage, data, '/qcoutcomes');}
    } else if (qcp.isPageForUQC){
      qc_outcomes_view.addUQCAnnotationLink ();
    }
    qc_outcomes_view.fetchAndProcessQC('results_summary', '/qcoutcomes', callAfterGettingOutcomes);
  });

  $("#menu #links .uqcClickable").click(function(e) {
      var callAfterGettingOutcomes = function (data) {
        launchUtilityQCProcesses(qcp.isRunPage, data, '/qcoutcomes');}
      qc_outcomes_view.fetchAndProcessQC('results_summary', '/qcoutcomes', callAfterGettingOutcomes);
      $("#menu #links .uqcClickable").remove();
  });
  
  var _getColourByUQCOutcome = function (uqcOutcome) {
      var colour = "grey";
      if (uqcOutcome === "Accepted"){
        colour = "green";
      } else if (uqcOutcome === "Rejected") {
        colour = "red";
      }
      return colour;
    };

  var launchUtilityQCProcesses = function (isRunPage, qcOutcomes, qcOutcomesURL) {
    try {
      if ( typeof isRunPage !== 'boolean' ||
           typeof qcOutcomes !== 'object' ||
           typeof qcOutcomesURL !== 'string' ) {
        throw 'Invalid parameter type.';
      }

      if ( typeof qcOutcomes.uqc === 'undefined' ) {
        throw 'uqc outcomes cannot be undefined.';
      }
      var prevOutcomes;
      if ( isRunPage ) {
        prevOutcomes = qcOutcomes.uqc;
      } else {
        prevOutcomes = qcOutcomes.uqc;
        $("#results_summary .lane").first()
                                   .append('<span class="library_uqc_overall_controls"></span>');
      }
      //Cut process if there is nothing to qc
      if ( $('.lane_mqc_control').length === 0 ) {
        return;
      }
      $('.lane_mqc_control').each(function (index, element) {
        var $element = $(element);
        var rowId = $element.closest('tr').attr('id');

        if ( typeof rowId === 'string' ) {
          var rptKey = qc_utils.rptKeyFromId(rowId);
          var isLaneKey = qc_utils.isLaneKey(rptKey);

          if (!isLaneKey) {
            var $libraryBrElement = $($element.parent()[0].nextElementSibling).find('br');
            $libraryBrElement[0].insertAdjacentHTML('beforebegin', '<span class="library_uqc_control"></span>');
            $element = $($libraryBrElement.prev());
          }

          var outcome = typeof prevOutcomes[rptKey] !== 'undefined' ? prevOutcomes[rptKey].uqc_outcome
                                                                    : undefined;
          var uqcAbleMarkColour = _getColourByUQCOutcome(outcome);            
          $element.css("padding-right", "5px").css("padding-left", "10px").css("background-color", uqcAbleMarkColour);
          var obj = $(qc_utils.buildIdSelector(rowId)).find('.lane_mqc_control');
        }
      });
    } catch (ex) {
      qc_utils.displayError('Error while initiating utility QC interface. ' + ex);
    }
  };

  //Required to show error messages from the mqc process.
  $("#results_summary").before('<ul id="ajax_status"></ul>');

  //Preload images for working icon
  $('<img/>')[0].src = "/static/images/waiting.gif";
  //Preload rest of icons
  $('<img/>')[0].src = "/static/images/tick.png";
  $('<img/>')[0].src = "/static/images/cross.png";
  $('<img/>')[0].src = "/static/images/padlock.png";
  $('<img/>')[0].src = "/static/images/circle.png";

  $("#summary_to_csv").click(function(e) {
    e.preventDefault();
    var table_html = $('#results_summary')[0].outerHTML;
    var formated_table = format_for_csv.format(table_html);
    formated_table.tableExport({type:'csv', fileName:'summary_data'});
  });

  plots.plots_on_view('.results_full_lane_contents', 2000);
});