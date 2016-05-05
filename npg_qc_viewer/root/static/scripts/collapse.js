/*
* Author:        Nadeem Faruque
*
* Copyright (C) 2014 Genome Research Ltd.
*
* This file is part of NPG software.
*
* NPG is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

/************************************************************************************
*
* Make and control collapsible sections of the SeqQC page.
*
* Dependencies: jQuery library
*
************************************************************************************/

/*
* Dynamically synchronously loads a script, which will be cached by a browser.
* Returns true if loading was successful, otherwise returns false.
* Loading is performed by an AJAX call, so 'same origin' policy applies.
*/

define(['jquery'],function(jQuery) {
return {
init: function() {
    // Register all collapsers as closed ones 
    jQuery(".collapser").addClass("collapser_open");

    // describe toggle behaviour of collapsers
    jQuery(".collapser").click(function(){
	    if(jQuery(this).hasClass("collapser_closed")) {
		jQuery(this).removeClass("collapser_closed");
		jQuery(this).addClass("collapser_open");
		jQuery(this).next("div").slideDown('fast');
	    } else {
		jQuery(this).removeClass("collapser_open");
		jQuery(this).addClass("collapser_closed");
		jQuery(this).next("div").slideUp('fast');
	    }
	    return false;
	});

    // manipulate LANE appearance
    //collapse all lanes
    jQuery("#collapse_all_lanes").click(function(){
	    //	    jQuery(this).hide()
		//		jQuery("#expand_all_lanes").show()
		jQuery("div.results_full_lane > h3.collapser_open").click();
		//		jQuery(".results_full_lane_body").slideUp('fast')
		return false;
	});
    
    //expand all lanes
    jQuery("#expand_all_lanes").click(function(){
	    //	    jQuery(this).hide()
	    //		jQuery("#collapse_all_lanes").show()
		//		jQuery(".results_full_lane_body").slideDown('fast')
		jQuery("div.results_full_lane > h3.collapser_closed").click()
		return false;
	});

    // manipulate TEST RESULT appearance
    //expand all results
    jQuery("#expand_all_results").click(function(){
	    jQuery("div.result_full > h2.collapser_closed").click();
	    return false;
	});

    //collapse all results
    jQuery("#collapse_all_results").click(function(){
	    jQuery("div.result_full > h2.collapser_open").click();
	    return false;
	});

	// collapse h2
	jQuery('.collapse_h2').click(function(){
		jQuery("h2.collapser_open:contains(" + $(this).data('section') + ")").click();
		return false;
	});

	// expand h2
	jQuery('.expand_h2').click(function(){
		jQuery("h2.collapser_closed:contains(" + $(this).data('section') + ")").click();
		return false;
	});

	// collapse h3
	jQuery('.collapse_h3').click(function(){
		jQuery("h3.collapser_open:contains(" + $(this).data('section') + ")").click();
		return false;
	});

	// expand h3
	jQuery('.expand_h3').click(function(){
		jQuery("h3.collapser_closed:contains(" + $(this).data('section') + ")").click();
		return false;
	});

	// collapse phix
	jQuery('#collapse_phix').click(function(){
		jQuery("h3.collapser_open:contains('#168')").click();
		jQuery("h2.collapser_open:contains('phix')").click();
		return false;
	});

	// expand phix
	jQuery('#expand_phix').click(function(){
		jQuery("h3.collapser_closed:contains('#168')").click();
		jQuery("h2.collapser_closed:contains('phix')").click();
		return false;
	});

    // Since javascript is active we can collapse sections and reveal the menu
    jQuery("#collapse_menu").show();
},

}
});


