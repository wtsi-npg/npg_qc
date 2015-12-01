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

require(['scripts/manual_qc', 'scripts/manual_qc_ui', 'scripts/format_for_csv', 'insert_size_lib', 'adapter_lib', 'mismatch_lib', 'unveil', 'table-export'],
function( manual_qc, manual_qc_ui, format_for_csv ,insert_size, adapter, mismatch, unveil) {
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

  var overlap = function (s1, h1, s2, h2) {
    var o1s, o1e, o2s, o2e;
    if ( h1 >= h2 ) {
      o1s = s1; o1e = s1 + h1;
      o2s = s2; o2e = s2 + h2;
    } else {
      o1s = s2; o1e = s2 + h2;
      o2s = s1; o2e = s1 + h1;
    }

    if ( (o2s >= o1s && o2s <= o1e) || (o2e >= o1s && o2e <= o1e) ) {
      return true;
    } else {
      return false;
    }
  } 

  $(window).on('scroll resize lookup', function() {
    var threshold = 2000;
    var $w = $(window);
    var wt = $w.scrollTop() - threshold;
    var viewHeight = $w.height() + (2 * threshold);

    $('.results_full_lane').each(function (i, obj) {
      var self = $(this);
      var selfTop = self.offset().top;

      if ( overlap( wt, viewHeight, selfTop, self.height() ) ) {
        if (self.data('inView') === undefined || self.data('inView') == 0) {
          window.console.log("Building plots " + i);
          self.data('inView', 1);
          self.find('.bcviz_insert_size').each(function () {
            var self = $(this);
            var parent = self.parent();
            var d = self.data('check'),
                w = self.data('width') || 650,
                h = self.data('height') || 300,
                t = self.data('title') || _getTitle('Insert Sizes : ',d);
            var chart = insert_size.drawChart({'data': d, 'width': w, 'height': h, 'title': t});
            //Removing data from page to free memory
            //self.removeAttr('data-check data-width data-height data-title');
            //Nulling variables to ease GC
            d = null; w = null; h = null; t = null;

            if (chart != null) {
              if (chart.svg != null) {
                div = $(document.createElement("div"));
                div.append(function() { return chart.svg.node(); } );
                div.addClass('chart');
                self.append(div);
              }
            }
            parent.css('min-height', parent.height() + 'px');
          });
          self.find('.bcviz_adapter').each(function () {
            var self = $(this);
            var parent = self.parent();
            var d = self.data('check'),
                h = self.data('height') || 200,
                t = self.data('title') || _getTitle('Adapter Start Count : ', d);

            // override width to ensure two graphs can fit side by side
            var w = jQuery(this).parent().width() / 2 - 40;
            var chart = adapter.drawChart({'data': d, 'width': w, 'height': h, 'title': t});
            //self.removeAttr('data-check data-height data-title');
            d = null; h = null; t = null;

            var fwd_div = $(document.createElement("div"));
            if (chart != null && chart.svg_fwd != null) { fwd_div.append( function() { return chart.svg_fwd.node(); } ); }
            fwd_div.addClass('chart_left');
            rev_div = $(document.createElement("div"));
            if (chart != null && chart.svg_rev != null) { rev_div.append( function() { return chart.svg_rev.node(); } ); }
            rev_div.addClass('chart_right');
            self.append(fwd_div,rev_div);
            parent.css('min-height', parent.height() + 'px');
          });
          self.find('.bcviz_mismatch').each(function () {
            var self = $(this);
            var parent = self.parent();
            var d = self.data('check'),
                h = self.data('height'),
                t = self.data('title') || _getTitle('Mismatch : ', d);

            // override width to ensure two graphs can fit side by side
            var w = parent.width() / 2 - 90;
            var chart = mismatch.drawChart({'data': d, 'width': w, 'height': h, 'title': t});
            //self.removeAttr('data-check data-height data-title');
            d = null; h = null; t = null;

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
          });
        }
      } else {
        if (self.data('inView') == 1) {
          window.console.log("Destroying plots " + i);
          self.data('inView', 0);
          self.find('.bcviz_insert_size').empty();
          self.find('.bcviz_adapter').empty();
          self.find('.bcviz_mismatch').empty();
        }
      }
    });
  });
});

