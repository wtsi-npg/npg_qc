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
        w = jQuery(this).data('width');
        h = jQuery(this).data('height');
        k = jQuery(this).data('key');
        t = jQuery(this).data('title');
        chart = insert_size.drawChart({'data': d, 'width': w, 'height': h, 'title': t}); 
        jQuery('#bcviz_insert_size_'+k).append( function() { return chart.svg.node(); } );
    });
	
	jQuery('.bcviz_adapter').each(function(i) { 
        d = jQuery(this).data('check');
        h = jQuery(this).data('height');
        k = jQuery(this).data('key');
        t = jQuery(this).data('title');
		// override width to ensure two graphs can fit side by side
		w = jQuery(this).parent().width() / 2 - 40;
		chart = adapter.drawChart({'data': d, 'width': w, 'height': h, 'title': t}); 
        jQuery('#bcviz_adapter_fwd_'+k).append( function() { return chart.svg_fwd.node(); } );
        jQuery('#bcviz_adapter_rev_'+k).append( function() { return chart.svg_rev.node(); } );
	});

	jQuery('.bcviz_mismatch').each(function(i) { 
        d = jQuery(this).data('check');
        h = jQuery(this).data('height');
        k = jQuery(this).data('key');
        t = jQuery(this).data('title');
		// override width to ensure two graphs can fit side by side
		w = jQuery(this).parent().width() / 2 - 90;
		chart = mismatch.drawChart({'data': d, 'width': w, 'height': h, 'title': t}); 
        jQuery('#bcviz_mismatch_fwd_'+k).append( function() { return chart.svg_fwd.node(); } );
        jQuery('#bcviz_mismatch_rev_'+k).append( function() { return chart.svg_rev.node(); } );
        jQuery('#bcviz_mismatch_legend_'+k).append( function() { return chart.svg_legend.node(); } );
	});

});
