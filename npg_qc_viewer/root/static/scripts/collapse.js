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
* Example:
*
*   requirejs(['collapse'], function( collapse ) {
*     var actionAfterCollapseToggle = function () {
*       alert('There was a collapse toggle!!!');
*     };
*
*     collapse.init(actionAfterCollapseToggle);
*   });
*
*
*
************************************************************************************/

/* globals $, define */

"use strict";
define(['jquery'], function() {
  return {
    init: function(afterCollapseToggle) {

      var _callAfterCollapseToggle = function () {
        if( typeof afterCollapseToggle === 'function' ) {
          afterCollapseToggle();
        }
      };

      var _toggleCollapseStatus = function(element, callback) {
        var $element = $(element);
        if($element.hasClass('collapser_closed')) {
          $element.removeClass('collapser_closed')
                  .addClass('collapser_open');
        } else {
          $element.removeClass('collapser_open')
                  .addClass('collapser_closed');
        }
        //Toggle next <div> (all results) and <h4> (references, for lanes)
        $element.nextAll('div,h4').toggle(0);
        if( typeof callback === 'function' ) {
          callback();
        }
      };

      var collapsers = $('.collapser');

      // Register all collapsers as open ones
      collapsers.addClass('collapser_open');

      // Describe toggle behaviour of collapsers
      collapsers.click(function(event) {
        event.preventDefault();
        event.stopPropagation();
        _toggleCollapseStatus(this, _callAfterCollapseToggle);
      });

      /* Manipulate LANE appearance */
      //Collapse all lanes
      $('#collapse_all_lanes').click(function(event) {
        event.preventDefault();
        event.stopPropagation();
        $('div.results_full_lane > h3.collapser_open').each(function(index, obj) {
          _toggleCollapseStatus(obj);
        });
        _callAfterCollapseToggle();
      });

      //Expand all lanes
      $('#expand_all_lanes').click(function(){
        event.preventDefault();
        event.stopPropagation();
        $('div.results_full_lane > h3.collapser_closed').each(function(index, obj) {
          _toggleCollapseStatus(obj);
        });
        _callAfterCollapseToggle();
      });

      /* Manipulate TEST RESULT appearance */
      //Expand all results
      $('#expand_all_results').click(function(){
        event.preventDefault();
        event.stopPropagation();
        $('div.result_full > h2.collapser_closed').each(function(index, obj) {
          _toggleCollapseStatus(obj);
        });
        _callAfterCollapseToggle();
      });

      //Collapse all results
      $('#collapse_all_results').click(function(){
        event.preventDefault();
        event.stopPropagation();
        $('div.result_full > h2.collapser_open').each(function(index, obj) {
          _toggleCollapseStatus(obj);
        });
        _callAfterCollapseToggle();
      });

      //Collapse h2
      $('.collapse_h2').click(function(){
        event.preventDefault();
        event.stopPropagation();
        $('h2.collapser_open:contains(' + $(this).data('section') + ')')
                                                 .each(function(index, obj) {
          _toggleCollapseStatus(obj);
        });
        _callAfterCollapseToggle();
      });

      //Expand h2
      $('.expand_h2').click(function(){
        event.preventDefault();
        event.stopPropagation();
        $('h2.collapser_closed:contains(' + $(this).data('section') + ')')
                                                   .each(function(index, obj) {
          _toggleCollapseStatus(obj);
        });
        _callAfterCollapseToggle();
      });

      //Collapse h3
      $('.collapse_h3').click(function(){
        event.preventDefault();
        event.stopPropagation();
        $('h3.collapser_open:contains(' + $(this).data('section') + ')')
                                                 .each(function(index, obj) {
          _toggleCollapseStatus(obj);
        });
        _callAfterCollapseToggle();
      });

      //Expand h3
      $('.expand_h3').click(function(){
        event.preventDefault();
        event.stopPropagation();
        $('h3.collapser_closed:contains(' + $(this).data('section') + ')')
                                                   .each(function(index,obj) {
          _toggleCollapseStatus(obj);
        });
        _callAfterCollapseToggle();
      });

      //Since javascript is active we can collapse sections and reveal the menu
      $('#collapse_menu').show();
    },
  };
});
