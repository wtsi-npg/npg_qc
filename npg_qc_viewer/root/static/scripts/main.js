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
  'scripts/plots',
  'scripts/format_for_csv',
  'unveil',
  'table-export'
],
function( manual_qc, manual_qc_ui, plots, format_for_csv, unveil) {
  //Setup for heatmaps to load on demand.
  $(document).ready(function(){
    $("img").unveil(2000);

    // Getting the run_id from the title of the page using the qc part too.
    var runTitleParserResult = new NPG.QC.RunTitleParser().parseIdRun($(document)
                                                          .find("title")
                                                          .text());

    var classNameForOutcome = function (qc_outcome) {
      var new_class = '';
      if( qc_outcome.mqc_outcome === 'Accepted final' ) {
        new_class = 'passed';
      }
      return new_class;
    };

    var processOutcomes = function (outcomes, rowClass) {
      var rpt_keys = Object.keys(outcomes);

      for (var i = 0; i < rpt_keys.length; i++) {
        var rpt_key = rpt_keys[i];
        var qc_outcome = outcomes[rpt_key];

        var new_class = classNameForOutcome(qc_outcome) ;
        $("." + rowClass + "[data-rpt_key='" + rpt_key + "']").addClass(new_class);
      }
    }

    var data = { };
    $('.lane').each(function (i, obj) {
      $obj = $(obj);
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
      processOutcomes(data.lib, 'tag_info');
      processOutcomes(data.seq, 'lane');
    });

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

