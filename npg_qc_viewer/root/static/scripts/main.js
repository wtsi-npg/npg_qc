require.config({
  baseUrl: '/static',
  catchError: true,
  paths: {
    jquery: 'bower_components/jquery/dist/jquery',
    d3: 'bower_components/d3/d3.min',
    insert_size_lib: 'bower_components/bcviz/src/qcjson/insertSizeHistogram',
    adapter_lib: 'bower_components/bcviz/src/qcjson/adapter',
    mismatch_lib: 'bower_components/bcviz/src/qcjson/mismatch',
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

function _getTitle(prefix, d) {
    var t = prefix;
    if (d.id_run) { t = t + 'run ' + d.id_run; }
    if (d.position) { t = t + ', lane ' + d.position; }
    if (d.tag_index) { t = t + ', tag ' + d.tag_index; }
    return t;
}

require( ['scripts/manual_qc', 'scripts/manual_qc_ui', 'scripts/format_for_csv', 'scripts/display_on_demand', 'insert_size_lib', 'adapter_lib', 'mismatch_lib', 'unveil', 'table-export'],
function( manual_qc, manual_qc_ui, format_for_csv, disp_on_view, insert_size, adapter, mismatch, unveil) {
  //Setup for heatmaps to load on demand.
  $(document).ready(function(){
    $("img").unveil(2000);

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

  var element = disp_on_view.buildDisplayOnViewElement(
      '.results_full_lane_contents',
      2000,
      function (i, obj) {
        var self = $(obj);
        self.find('.bcviz_insert_size').each(function () {
          var self = $(this);
          var parent = self.parent();
          var d = $.extend( true, {}, self.data('check') ),
              w = self.data('width') || 650,
              h = self.data('height') || 300,
              t = self.data('title') || _getTitle('Insert Sizes : ',d);
          var chart = insert_size.drawChart({'data': d, 'width': w, 'height': h, 'title': t});

          if (chart != null) {
            if (chart.svg != null) {
              var div = $(document.createElement("div"));
              div.append(function() { return chart.svg.node(); } );
              div.addClass('chart');
              self.append(div);
              div = null;
            }
          }
          parent.css('min-height', parent.height() + 'px');
          //Nulling variables to ease GC
          d = null, w = null, h = null, t = null, parent = null, self = null;
        });
        self.find('.bcviz_adapter').each(function () {
          var self = $(this);
          var parent = self.parent();
          var d = $.extend( true, {}, self.data('check') ),
              h = self.data('height') || 200,
              t = self.data('title') || _getTitle('Adapter Start Count : ', d);

          // override width to ensure two graphs can fit side by side
          var w = jQuery(this).parent().width() / 2 - 40;
          var chart = adapter.drawChart({'data': d, 'width': w, 'height': h, 'title': t});

          var fwd_div = $(document.createElement("div"));
          if (chart != null && chart.svg_fwd != null) { fwd_div.append( function() { return chart.svg_fwd.node(); } ); }
          fwd_div.addClass('chart_left');
          rev_div = $(document.createElement("div"));
          if (chart != null && chart.svg_rev != null) { rev_div.append( function() { return chart.svg_rev.node(); } ); }
          rev_div.addClass('chart_right');
          self.append(fwd_div,rev_div);
          parent.css('min-height', parent.height() + 'px');
          //Nulling variables to ease GC
          d = null; w = null,  h = null; t = null, chart = null, fwd_div = null, rev_div = null, parent = null, self = null;
        });
        self.find('.bcviz_mismatch').each(function () {
          var self = $(this);
          var parent = self.parent();
          var d = $.extend( true, {}, self.data('check') ),
              h = self.data('height'),
              t = self.data('title') || _getTitle('Mismatch : ', d);

          // override width to ensure two graphs can fit side by side
          var w = parent.width() / 2 - 90;
          var chart = mismatch.drawChart({'data': d, 'width': w, 'height': h, 'title': t});

          var fwd_div = $(document.createElement("div"));
          if (chart != null && chart.svg_fwd != null) { fwd_div.append( function() { return chart.svg_fwd.node(); } ); }
          fwd_div.addClass('chart_left');

          var rev_div = $(document.createElement("div"));
          if (chart != null && chart.svg_rev != null) { rev_div.append( function() { return chart.svg_rev.node(); } ); }
          rev_div.addClass('chart_right');

          var leg_div = $(document.createElement("div"));
          if (chart != null && chart.svg_legend != null) { leg_div.append( function() { return chart.svg_legend.node(); } ); }
          leg_div.addClass('chart_legend');

          self.append(fwd_div,rev_div,leg_div);
          parent.css('min-height', parent.height() + 'px');
          //Nulling variables to ease GC
          d = null; w = null,  h = null; t = null, chart = null, fwd_div = null, rev_div = null, leg_div = null, parent = null, self = null;
        });
      },
      function (i, obj) {
        self = $(obj);
        self.find('.bcviz_insert_size').empty();
        self.find('.bcviz_adapter').empty();
        self.find('.bcviz_mismatch').empty();
      }
  );

  var elements = [element];
  disp_on_view.displayOnView(elements);
});

