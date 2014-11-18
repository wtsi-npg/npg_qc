/*
* Author:        Marina Gourtovaia
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
* Top-level callback for events and actions on loading a page.
* Dynamically loads all necessary libraries (apart fron jQuery, which has to be preloaded).
*
* Dependencies: jQuery library
*
************************************************************************************/

/*
* Dynamically synchronously loads a script, which will be cached by a browser.
* Returns true if loading was successful, otherwise returns false.
* Loading is performed by an AJAX call, so 'same origin' policy applies.
*/
function load_script(script_url) {
  var successflag=false;

  jQuery.ajax({
    async: false,
    cache: true,
    url: script_url,
    data: null,
    success: function() {
      successflag=true;
    },
    dataType: 'script'
  });
  return successflag;
} 


/*
* Action on loading the document.
* Sets AJAX defaults for the application. Loads and calls further
* js scripts and functions.
*/
$(document).ready(function() {

  jQuery.noConflict();

  //Create a placeholder for error messages
  jQuery("#content").before('<ul id="ajax_status" class="failed"></ul>');

  jQuery.ajaxSetup({ cache: false, 
                     global: true,
	             timeout: 90000
                  });

  jQuery("#ajax_status").ajaxError(function(ev, xhr, settings) {
    var msg = "ERROR";
    try {
      msg = xhr.status + " ERROR: " + xhr.statusText;
    } catch (e) {}
    jQuery(this).append("<li>" + msg + "</li>");
  });

  var loaded = load_script('/static/scripts/full_results.js');
  if (loaded) {
    display_contamination_check_results();
  }

  var loaded = load_script('/static/scripts/collapse.js');
  if (loaded) {
    make_collapsible_sections();
    jQuery("#collapse_all_phix").click();
  }

  if (typeof(load_mqc_widgets) != "undefined" && load_mqc_widgets == 1) {
    loaded = load_script('/static/scripts/npg_common.js');
    if (loaded) {
      loaded = load_script('/static/scripts/manual_qc.js');
    }
    if (loaded) {
      try {
        getQcState();
      } catch (e) {
        jQuery("#ajax_status").text(e);
        jQuery(".mqc").empty();
      }
    }
  }
});
