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
    window.console && console.log(err.requireType);
    window.console && console.log('modules: ' + err.requireModules);
    throw err;
};

require(['manual_qc','collapse','bcviz/insertSizeHistogram', 'bcviz/adapter', 'bcviz/mismatch'], 
function( manual_qc,  collapse,  insert_size,                 adapter,         mismatch) {

	collapse.init();

	if(typeof(load_mqc_widgets) != "undefined" && load_mqc_widgets == 1 ) {
		getQcState();
	} else {
	  jQuery('.lane_mqc_working').empty(); //There is no mqc so I just remove the working image.
	}

	jQuery('.bcviz_insert_size').each(function(i) { 
	  insert_size.drawChart(this); 
	});
	
	jQuery('.bcviz_adapter').each(function(i) { 
		// override width to ensure two graphs can fit side by side
		var width = jQuery(this).parent().width() / 2 - 40;
		adapter.drawChart(this,width); 
	});

	jQuery('.bcviz_mismatch').each(function(i) { 
		// override width to ensure two graphs can fit side by side
		var width = jQuery(this).parent().width() / 2 - 90;
		mismatch.drawChart(this,width); 
	});

});
