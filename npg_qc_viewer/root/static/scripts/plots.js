/*
 * Module to profide functionality to generate bcviz plots when they will come
 * into view. The module exposes one function which receives a selector and a
 * threshold as parameters. The selector is used to find DOM elements. Each
 * element is checked to confirm if it be in view or out of view. If it is in
 * view, bcviz plots will be generated for that element. If the element is not
 * in view and it has plots in it, they will be removed.
 *
 * Example:
 *
 *   plots_on_view('.results_full_lane_contents', 2000);
 *
 */
/* globals $: false, define: false, document: false */
/* jshint -W030, -W083 */
'use strict';
define([
  'jquery',
  'bower_components/bcviz/src/qcjson/insertSizeHistogram',
  'bower_components/bcviz/src/qcjson/adapter',
  'bower_components/bcviz/src/qcjson/mismatch',
  'scripts/modify_on_view'
], function(jQuery, insert_size, adapter, mismatch, mov) {
  var _getTitle = function (prefix, d) {
    var t = prefix;
    if (d.id_run) { t = t + 'run ' + d.id_run; }
    if (d.position) { t = t + ', lane ' + d.position; }
    if (d.tag_index) { t = t + ', tag ' + d.tag_index; }
    return t;
  };

  var plot_adapter = function(obj) {
    if(typeof(obj) === "undefined" || obj == null) {
      throw new TypeError("obj can not be undefined");
    }
    obj.find('.bcviz_adapter').each(function () {
      var self = $(this);
      if ( self.children().length === 0 ) {
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
        var rev_div = $(document.createElement("div"));
        if (chart != null && chart.svg_rev != null) { rev_div.append( function() { return chart.svg_rev.node(); } ); }
        rev_div.addClass('chart_right');
        self.append(fwd_div,rev_div);
        parent.css('min-height', parent.height() + 'px');
        //Nulling variables to ease GC
        d = null; w = null;  h = null; t = null; chart = null; fwd_div = null; rev_div = null; parent = null; self = null;
      }
    });
  };

  var plot_mismatch = function(obj) {
    if(typeof(obj) === "undefined" || obj == null) {
      throw new TypeError("obj can not be undefined");
    }
    obj.find('.bcviz_mismatch').each(function () {
      var self = $(this);
      if ( self.children().length === 0 ) {
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
        d = null; w = null;  h = null; t = null; chart = null; fwd_div = null; rev_div = null; leg_div = null; parent = null; self = null;
      }
    });
  };

  var plot_insert_size = function(obj) {
    if(typeof(obj) === "undefined" || obj == null) {
      throw new TypeError("obj can not be undefined");
    }
    obj.find('.bcviz_insert_size').each(function () {
      var self = $(this);
      if ( self.children().length === 0 ) {
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
        d = null; w = null; h = null; t = null; parent = null; self = null;
      }
    });
  };

  var plots_on_view = function (selectorFilter, threshold) {
    if(typeof(selectorFilter) === "undefined" || selectorFilter == null) {
      throw new TypeError("selectorFilter can not be undefined");
    }
    threshold = typeof threshold !== 'undefined' ? threshold : 2000;

    var element = mov.buildModifyOnViewElement(
      selectorFilter,
      threshold,
      function (i, obj) { //Display call back
        plot_adapter(obj);
        plot_mismatch(obj);
        plot_insert_size(obj);
      },
      function (i, obj) { // remove callback
        var plotsClasses = ['.bcviz_insert_size', '.bcviz_adapter', '.bcviz_mismatch'];
        for( var j = 0; j < plotsClasses.length; j++ ) {
          var plotContainer = obj.find(plotsClasses[j]);
          if ( plotContainer.children().length > 0 ) {
            plotContainer.empty();
          }
        }
      }
    );

    mov.modifyOnView([element], false);
  };

  return {
    plots_on_view : plots_on_view,
  };
});
