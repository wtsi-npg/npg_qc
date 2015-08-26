require.config({
    baseUrl: '/static',
  catchError: true,
    paths: {
        jquery: 'bower_components/jquery/jquery',
        d3: 'bower_components/d3/d3.min',
        insert_size_lib: 'bower_components/bcviz/src/qcjson/insertSizeHistogram',
        adapter_lib: 'bower_components/bcviz/src/qcjson/adapter',
        mismatch_lib: 'bower_components/bcviz/src/qcjson/mismatch',
        unveil: 'bower_components/jquery-unveil/jquery.unveil',
    },
    shim: {
        d3: {
            //makes d3 available automatically for all modules
            exports: 'd3'
        },
        unveil: ["jquery"]
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

require(['scripts/manual_qc', 'insert_size_lib', 'adapter_lib', 'mismatch_lib', 'unveil'],
function( manual_qc, insert_size, adapter, mismatch, unveil) {
  $("img").unveil(2000);

  //Required to show error messages from the mqc process.
  $("#results_summary").before('<ul id="ajax_status"></ul>');

  //Preload images for working icon
  $('<img/>')[0].src = "/static/images/waiting.gif";
  //Preload rest of icons
  $('<img/>')[0].src = "/static/images/tick.png";
  $('<img/>')[0].src = "/static/images/cross.png";
  $('<img/>')[0].src = "/static/images/padlock.png";

  //Read information about lanes from page.
  var lanes = []; //Lanes without previous QC, blank BG
  var lanesWithBG = []; //Lanes with previous QC, BG with colour
  //Select non-qced lanes.
  $('.lane_mqc_control').each(function (i, obj) {
    obj = $(obj);
    var parent = obj.parent();
    //Not considering lanes previously marked as passes/failed
    if(parent.hasClass('passed') || parent.hasClass('failed')) {
      lanesWithBG.push(parent);
    } else {
      var tag_index = obj.data('tag_index');
      if (typeof (tag_index) != undefined && tag_index != null){
        if(tag_index != 0 && tag_index != 888) {
          lanes.push(parent);
        }
      } else {
        lanes.push(parent);
      }
    }
  });

  // Getting the run_id from the title of the page using the qc part too.
  var runTitleParserResult = new NPG.QC.RunTitleParser().parseIdRun($(document).find("title").text());
  //If id_run //TODO move to object.
  if(typeof(runTitleParserResult) != undefined && runTitleParserResult != null) {
    var id_run = runTitleParserResult.id_run;
    var prodConfiguration = new NPG.QC.ProdConfiguration();

    if (runTitleParserResult.isRunPage) {
      window.console && console.log("Run page");
      var jqxhr = $.ajax({
        url: "/mqc/mqc_runs/" + id_run,
        cache: false
      }).done(function() {
        var control = new NPG.QC.RunMQCControl(prodConfiguration);
        var mqc_run_data = jqxhr.responseJSON;
        if(control.isStateForMQC(mqc_run_data)) {
          var DWHMatch = control.laneOutcomesMatch(lanesWithBG, mqc_run_data);
          if(DWHMatch.outcome) {
            control.initQC(jqxhr.responseJSON, lanes,
                function (mqc_run_data, runMQCControl, lanes) {
                  //Show working icons
                  for(var i = 0; i < lanes.length; i++) {
                    lanes[i].children('a').addClass('padded_anchor');
                    lanes[i].children('.lane_mqc_control').each(function(j, obj){
                      $(obj).html("<span class='lane_mqc_working'><img src='/static/images/waiting.gif' title='Processing request.'></span>");
                    });
                  }
                  runMQCControl.prepareLanes(mqc_run_data, lanes);
                },
                function () { //There is no mqc so I just remove the working image and padding for anchor
                  $('.lane_mqc_working').empty();
                }
            );
          } else {
            $("#ajax_status").append("<li class='failed_mqc'>"
                + "Conflicting data when comparing Data Ware House and Manual QC databases for run: "
                + id_run
                + ", lane: "
                + DWHMatch.position
                + ". Displaying of QC widgets aborted.</li>");
            //Clear progress icon
            $('.lane_mqc_working').empty();
          }
        } else {
          control.showMQCOutcomes(jqxhr.responseJSON, lanes);
        }
      }).fail(function(jqXHR, textStatus, errorThrown) {
        window.console && console.log( "error: " + errorThrown + " " + textStatus);
        $("#ajax_status").append("<li class='failed_mqc'>" + errorThrown + " " + textStatus + "</li>");
        //Clear progress icon
        $('.lane_mqc_working').empty();
      });
    } else {
      window.console && console.log("Run + Lane page");
      window.console && console.log("Run " + id_run);
      window.console && console.log("Position " + runTitleParserResult.position);

      var control = new NPG.QC.LanePageMQCControl(prodConfiguration);
      var mqc_run_data = {};
      var save_all = $($('.lane_mqc_save')[0]);
      save_all.data('link', {'individual_controls' : []});
      save_all.off("click").on("click", function() {
        var preliminaryOutcomes = 0;
        for (var i = 0; i < lanes.length; i++) {
          obj = $(lanes[i].children('.lane_mqc_control')[0]);
          var controller = obj.data('extra_handler');
          var tag_index  = obj.data('tag_index');
          window.console && console.log('tag_index ' + tag_index + ' outcome ' + controller.outcome);
          if (controller.outcome != controller.CONFIG_UNDECIDED) {
            preliminaryOutcomes++;
          } else {
            $("#ajax_status").append("<li class='failed_mqc'>"
                + "Tag " + tag_index + ' can not be undecided.</li>');
            break;
          }
        }
        if (preliminaryOutcomes == lanes.length) {
          for (var i = 0; i < lanes.length; i++) {
            obj = $(lanes[i].children('.lane_mqc_control')[0]);
            var controller = obj.data('extra_handler');
            controller.saveAsFinalOutcome();
          }
          $($('.lane_mqc_save')[0]).hide();
        }
      });
      if(true) {
        /*var DWHMatch = control.laneOutcomesMatch(lanesWithBG, mqc_run_data);*/
        if (true) /*(DWHMatch.outcome)*/ {
          control.initQC(mqc_run_data, lanes,
            function (mqc_run_data, runMQCControl, lanes) {
              //Show working icons
              for(var i = 0; i < lanes.length; i++) {
                lanes[i].children('.lane_mqc_control').each(function(j, obj){
                  obj = $(obj);
                  obj.html("<span class='lane_mqc_working'><img src='/static/images/waiting.gif' title='Processing request.'></span>");
                });
              }
              runMQCControl.prepareLanes(mqc_run_data, lanes);
            },
            function () { //There is no mqc so I just remove the working image and padding for anchor
              $('.lane_mqc_working').empty();
            }
          );
        } else {
          $("#ajax_status").append("<li class='failed_mqc'>"
              + "Conflicting data when comparing Data Ware House and Manual QC databases for run: "
              + id_run
              + ", lane: "
              + DWHMatch.position
              + ". Displaying of QC widgets aborted.</li>");
          //Clear progress icon
          $('.lane_mqc_working').empty();
        }
      } else {
        control.showMQCOutcomes(jqxhr.responseJSON, lanes);
      }
    }
  }

  jQuery('.bcviz_insert_size').each(function(i) {
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

  jQuery('.bcviz_mismatch').each(function() {
    var self = $(this)
    var d = jQuery(this).data('check'),
        h = jQuery(this).data('height'),
        t = jQuery(this).data('title') || _getTitle('Mismatch : ', d);

    // override width to ensure two graphs can fit side by side
    var w = jQuery(this).parent().width() / 2 - 90;
    var chart = mismatch.drawChart({'data': d, 'width': w, 'height': h, 'title': t});
    self.removeAttr('data-check data-height data-title');
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
  });
});
