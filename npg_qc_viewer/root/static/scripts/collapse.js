/*
* Author: Jaime Tovar <jmtc@sanger.ac.uk>
*
* Copyright (C) 2016 Genome Research Ltd.
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

/* globals $, define */

"use strict";
define(['jquery'], function() {
  return {
    init: function() {
      var collapsers = $('.collapser');
      // Register all collapsers as open ones
      collapsers.addClass('collapser_open');

      // Describe toggle behaviour of collapsers
      collapsers.click(function() {
        var self = $(this);
        if(self.hasClass('collapser_closed')) {
          self.removeClass('collapser_closed')
              .addClass('collapser_open');
          window.scrollBy(0, 1);
          window.scrollBy(0, -1);
        } else {
          self.removeClass('collapser_open')
              .addClass('collapser_closed');
        }

        //Toggle next <div> (all results) and <h4> (references, for lanes)
        self.nextAll('div,h4').toggle(0);
        return false;
      });

      /* Manipulate LANE appearance */
      //Collapse all lanes
      $('#collapse_all_lanes').click(function() {
        $('div.results_full_lane > h3.collapser_open').click();
        return false;
      });

      //Expand all lanes
      $('#expand_all_lanes').click(function(){
        $('div.results_full_lane > h3.collapser_closed').click();
        return false;
      });

      /* Manipulate TEST RESULT appearance */
      //Expand all results
      $('#expand_all_results').click(function(){
        $('div.result_full > h2.collapser_closed').click();
        return false;
      });

      //Collapse all results
      $('#collapse_all_results').click(function(){
        $('div.result_full > h2.collapser_open').click();
        return false;
      });

      //Collapse h2
      $('.collapse_h2').click(function(){
        $('h2.collapser_open:contains(' + $(this).data('section') + ')').click();
        return false;
      });

      //Expand h2
      $('.expand_h2').click(function(){
        $('h2.collapser_closed:contains(' + $(this).data('section') + ')').click();
        return false;
      });

      //Collapse h3
      $('.collapse_h3').click(function(){
        $('h3.collapser_open:contains(' + $(this).data('section') + ')').click();
        return false;
      });

      //Expand h3
      $('.expand_h3').click(function(){
        $('h3.collapser_closed:contains(' + $(this).data('section') + ')').click();
        return false;
      });

      //Since javascript is active we can collapse sections and reveal the menu
      $('#collapse_menu').show();
    },
  };
});
