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
* Rearrangments for full autoqc results
* Dependencies: jQuery library
*
************************************************************************************/

define(['jquery'], function(jQuery) {
return function() {

  // display check name above the tables?

  jQuery("div.result_full > h2:contains('contamination')").each(function() {
    
    var contam_header_element = jQuery(this);
    var contam_text = contam_header_element.text();
    var split_text = contam_text.split(',');
    var result_id = split_text[0];
    
    var refmatch_element;
    var ref_match_filter = result_id + ', ref match';
    ref_match_filter = "div.result_full > h2:contains('" + ref_match_filter + "')";
    jQuery(ref_match_filter).each(function() {
      refmatch_element = jQuery(this).next();
    });
    if (refmatch_element) {

      var new_height = refmatch_element.css('height');

      var result_div = contam_header_element.next();
      refmatch_element.parent().empty();

      var contam_tables = result_div.children(); 
      result_div.empty();
      result_div.append('<div></div>');
      result_div.children().append(contam_tables);

      result_div.children().css('float', 'left');
      refmatch_element.removeClass();
      result_div.append(refmatch_element);
      refmatch_element.css('float', 'right');

      contam_header_element.parent().next().css('clear', 'both');

      var delim = ':';
      split_text = contam_text.split(delim);
      if (split_text.length == 1) {
          delim = '|';
          split_text = contam_text.split(delim);
          delim = ' ' + delim;
      }
      contam_text = split_text[0] + ' and ref match';
      if (split_text.length > 1) {
          contam_text = contam_text + delim + split_text[1];
      }
      contam_header_element.text(contam_text);
      
      result_div.css('height', new_height);
    }
 });
};
});
