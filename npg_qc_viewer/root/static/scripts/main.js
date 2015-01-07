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

require(['npg_common','manual_qc','collapse','full_results','bcviz/insertSizeHistogram', 'bcviz/adapter', 'bcviz/mismatch'], 
function( npg_common,  manual_qc,  collapse,  full_results,  insert_size,                 adapter,         mismatch) {

	full_results();
	collapse.init();

	try {
		getQcState();
	} catch (e) {
		jQuery("#ajax_status").text(e);
		jQuery(".mqc").empty();
	}

	jQuery('.bcviz_insert_size').each(function(i) { insert_size(this); });
	
	jQuery('.bcviz_adapter').each(function(i) { 
		// override width to ensure two graphs can fit side by side
		var width = jQuery(this).parent().width() / 2 - 40;
		adapter(this,width); 
	});

	jQuery('.bcviz_mismatch').each(function(i) { 
		// override width to ensure two graphs can fit side by side
		var width = jQuery(this).parent().width() / 2 - 90;
		mismatch(this,width); 
	});

});
