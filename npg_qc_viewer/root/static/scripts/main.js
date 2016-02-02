require.config({
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

require.onError = function (err) {
    window.console && console.log(err.requireType);
    window.console && console.log('modules: ' + err.requireModules);
    throw err;
};

require([
  'scripts/manual_qc',
  'scripts/manual_qc_ui',
  'scripts/qc_outcomes_view',
  'scripts/plots',
  'scripts/format_for_csv',
  'unveil',
  'table-export'
],
function( manual_qc, manual_qc_ui, qc_outcomes_view, plots, format_for_csv, unveil) {
  //Setup for heatmaps to load on demand.
  $(document).ready(function(){
    $("img").unveil(2000);
    qc_outcomes_view.processQC('results_summary', '/qcoutcomes', NPG.QC.launchManualQCProcesses);
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

