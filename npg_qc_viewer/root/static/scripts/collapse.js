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

function make_collapsible_sections() {
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

    // Since javascript is active we can collapse sections and reveal the menu
    jQuery("#collapse_menu").show();
}

// manipulate Specific Test appearance
//expand all instances of a test
function collapse_h2_section(queryText) {
    jQuery("h2.collapser_open:contains(" + queryText + ")").click();
    return false;
}

//expand all instances of a test
function expand_h2_section(queryText) {
    jQuery("h2.collapser_closed:contains(" + queryText + ")").click();
    return false;
}

// manipulate Specific Test appearance
//expand all instances of a test
function collapse_h3_section(queryText) {
    jQuery("h3.collapser_open:contains(" + queryText + ")").click();
    return false;
}

//expand all instances of a test
function expand_h3_section(queryText) {
    jQuery("h3.collapser_closed:contains(" + queryText + ")").click();
    return false;
}

