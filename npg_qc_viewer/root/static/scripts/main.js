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
  var QC_OUTCOMES = '/qcoutcomes';
  
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
        NPG.QC.launchManualQCProcesses(qcp.isRunPage, data, QC_OUTCOMES);}
    } else if (qcp.isPageForUQC) {
      qc_outcomes_view.addUQCAnnotationLink("#menu #links > ul:eq(3)", function() {
        var callAfterGettingOutcomes = function (data) {
          launchUtilityQCProcesses(qcp.isRunPage, data, QC_OUTCOMES);
        }
        fetchAndProcessQC('results_summary', QC_OUTCOMES, callAfterGettingOutcomes);
      });
    }
    qc_outcomes_view.fetchAndProcessQC('results_summary', QC_OUTCOMES, callAfterGettingOutcomes);
  });

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