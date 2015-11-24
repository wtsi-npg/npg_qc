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

  $(window).on("scroll resize lookup", function () {
    var insertSizeCache = jQuery('.bcviz_insert_size');
    var adapterCache = jQuery('.bcviz_adapter');
    var mismatchCache = jQuery('.bcviz_mismatch');
    var threshold = 2000;
    var self = $(this);
    var wt = self.scrollTop() - threshold, wb = wt + self.height() + threshold;

    insertSizeCache.each(function(i) {
      var self = $(this);
      var parent = self.parent();
      var parentTop = parent.offset().top;
      var parentBot = parent.offset().top + parent.height();

      if ((parentTop > wt && parentTop < wb) || (parentBot > wt && parentBot < wb)) {
        if (self.data('inside') === undefined || self.data('inside') == 0) {

          //var self = $(this);
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

          self.data('inside', 1);
        }
      } else {
        if (self.data('inside') == 1) {
          self.empty();
          self.data('inside', 0);
        }
      }
    });

    adapterCache.each(function() {
      var self = $(this);
      var parent = self.parent();
      var parentTop = parent.offset().top;
      var parentBot = parent.offset().top + parent.height();

      if ((parentTop > wt && parentTop < wb) || (parentBot > wt && parentBot < wb)) {
        if (self.data('inside') === undefined || self.data('inside') == 0) {

          //var self = $(this);
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

          self.data('inside', 1);
        }
      } else {
        if (self.data('inside') == 1) {
          self.empty();
          self.data('inside', 0);
        }
      }
    });

    mismatchCache.each(function () {
      var self = $(this);
      var parent = self.parent();
      var parentTop = parent.offset().top;
      var parentBot = parent.offset().top + parent.height();

      if ((parentTop > wt && parentTop < wb) || (parentBot > wt && parentBot < wb)) {
        if (self.data('inside') === undefined || self.data('inside') == 0) {
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
          
          self.data('inside', 1);
        }
      } else {
        if (self.data('inside') == 1) {
          self.empty();
          self.data('inside', 0);
        }
      }
    });

    //window.console.log($('*').length);
  });

  /*jQuery('.bcviz_insert_size').each(function(i) {
    var self = $(this);
    var d = self.data('check'),
        w = self.data('width') || 650,
        h = self.data('height') || 300,
        t = self.data('title') || _getTitle('Insert Sizes : ',d);
    var chart = insert_size.drawChart({'data': d, 'width': w, 'height': h, 'title': t});
    //Removing data from page to free memory
    self.removeAttr('data-check data-width data-height data-title');
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
  });

  jQuery('.bcviz_adapter').each(function() {
    var self = $(this);
    var d = self.data('check'),
        h = self.data('height') || 200,
        t = self.data('title') || _getTitle('Adapter Start Count : ', d);

    // override width to ensure two graphs can fit side by side
    var w = jQuery(this).parent().width() / 2 - 40;
    var chart = adapter.drawChart({'data': d, 'width': w, 'height': h, 'title': t});
    self.removeAttr('data-check data-height data-title');
    d = null; h = null; t = null;

    var fwd_div = $(document.createElement("div"));
    if (chart != null && chart.svg_fwd != null) { fwd_div.append( function() { return chart.svg_fwd.node(); } ); }
    fwd_div.addClass('chart_left');
    rev_div = $(document.createElement("div"));
    if (chart != null && chart.svg_rev != null) { rev_div.append( function() { return chart.svg_rev.node(); } ); }
    rev_div.addClass('chart_right');
    self.append(fwd_div,rev_div);
  });

  jQuery('.bcviz_mismatch').parent().on('mouseenter', function () {
    window.console.log($('*').length);
    $(this).children('.bcviz_mismatch').each(function() {
      var self = $(this)
      var d = jQuery(this).data('check'),
          h = jQuery(this).data('height'),
          t = jQuery(this).data('title') || _getTitle('Mismatch : ', d);

      // override width to ensure two graphs can fit side by side
      var w = jQuery(this).parent().width() / 2 - 90;
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
      window.console.log($('*').length);
    });
  }).on('mouseleave', function () {
    window.console.log($('*').length);
    $(this).children('.bcviz_mismatch').empty();
    window.console.log($('*').length);
  });*/
});
