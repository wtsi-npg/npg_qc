require.config({
    baseUrl: '/static/scripts',
	catchError: true,
    paths: {
        jquery: 'jquery-2.0.3',
        d3: 'd3'
    },
    shim: {
        d3: {
            //makes d3 available automatically for all modules
            exports: 'd3'
        }
    }
});

require.onError = function (err) {
    console.log(err.requireType);
    console.log('modules: ' + err.requireModules);
    throw err;
};

function _getTitle(prefix, d) {
    var t = prefix;
    if (d.id_run) { t = t + 'run ' + d.id_run; }
    if (d.position) { t = t + ', lane ' + d.position; }
    if (d.tag_index) { t = t + ', tag ' + d.tag_index; }
    return t;
}

require(['npg_common','manual_qc','collapse','bcviz/insertSizeHistogram', 'bcviz/adapter', 'bcviz/mismatch'], 
function( npg_common,  manual_qc,  collapse,  insert_size,                 adapter,         mismatch) {

	collapse.init();

	try {
		getQcState();
	} catch (e) {
		jQuery("#ajax_status").text(e);
		jQuery(".mqc").empty();
	}

	jQuery('.bcviz_insert_size').each(function(i) { 
        d = jQuery(this).data('check');
        w = jQuery(this).data('width') || 650;
        h = jQuery(this).data('height') || 300;
        t = jQuery(this).data('title') || _getTitle('Insert Sizes : ',d);
        chart = insert_size.drawChart({'data': d, 'width': w, 'height': h, 'title': t}); 
        if (chart != null) {
            if (chart.svg != null) {
        div = document.createElement("div");
        jQuery(div).append(function() { return chart.svg.node(); } );
        jQuery(div).addClass('chart');
        jQuery(this).append(div);
            }
        }
    });
	
	jQuery('.bcviz_adapter').each(function(i) { 
        d = jQuery(this).data('check');
        h = jQuery(this).data('height') || 200;
        t = jQuery(this).data('title') || _getTitle('Adapter Start Count : ', d);

		// override width to ensure two graphs can fit side by side
		w = jQuery(this).parent().width() / 2 - 40;
		chart = adapter.drawChart({'data': d, 'width': w, 'height': h, 'title': t}); 
        fwd_div = document.createElement("div");
        if (chart != null && chart.svg_fwd != null) { jQuery(fwd_div).append( function() { return chart.svg_fwd.node(); } ); }
        jQuery(fwd_div).addClass('chart_left');
        rev_div = document.createElement("div");
        if (chart != null && chart.svg_rev != null) { jQuery(rev_div).append( function() { return chart.svg_rev.node(); } ); }
        jQuery(rev_div).addClass('chart_right');
        jQuery(this).append(fwd_div,rev_div);
	});

	jQuery('.bcviz_mismatch').each(function(i) { 
        d = jQuery(this).data('check');
        h = jQuery(this).data('height');
        t = jQuery(this).data('title') || _getTitle('Mismatch : ', d);

		// override width to ensure two graphs can fit side by side
		w = jQuery(this).parent().width() / 2 - 90;
		chart = mismatch.drawChart({'data': d, 'width': w, 'height': h, 'title': t}); 
        fwd_div = document.createElement("div");
        if (chart != null && chart.svg_fwd != null) { jQuery(fwd_div).append( function() { return chart.svg_fwd.node(); } ); }
        jQuery(fwd_div).addClass('chart_left');

        rev_div = document.createElement("div");
        if (chart != null && chart.svg_rev != null) { jQuery(rev_div).append( function() { return chart.svg_rev.node(); } ); }
        jQuery(rev_div).addClass('chart_right');

        leg_div = document.createElement("div");
        if (chart != null && chart.svg_legend != null) { jQuery(leg_div).append( function() { return chart.svg_legend.node(); } ); }
        jQuery(leg_div).addClass('chart_legend');

        jQuery(this).append(fwd_div,rev_div,leg_div);
	});

});
