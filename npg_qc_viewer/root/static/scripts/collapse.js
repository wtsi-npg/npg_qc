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

        // Manual toggle as $.toggle() is considerably slower for large number of
        // elements
        if ( element.is(':visible') ) {
          element.css('display', 'none');
        } else {
          element.css('display', 'block');
        }
        if( typeof callback === 'function' ) {
          callback();
        }
      };

      var collapsers = $('.collapser');

      // Describe toggle behaviour of collapsers
      collapsers.click(function(event) {
        event.preventDefault();
        event.stopPropagation();
        var toCollapse = $(this).nextAll('div');
        _toggleCollapseStatus(toCollapse, _callAfterCollapseToggle);
      });

      var allHeaders = $('#results_full h2.collapser');
      var allChecks = [];

      //To keep for collapse/expand all
      $.each(allHeaders, function(index, obj) {
        var nextDiv = $($(obj).next('div'));
        allChecks.push(nextDiv);
      });

      /* Manipulate CHECK RESULT appearance */
      //Expand all results
      $('#expand_all_results').click(function(event) {
        event.preventDefault();
        event.stopPropagation();
        $.each(allChecks, function(index, obj) {
          if( ! obj.is(':visible') ) {
            _toggleCollapseStatus(obj)
          }
        });
        _callAfterCollapseToggle();
      });

      //Collapse all results
      $('#collapse_all_results').click(function(event) {
        event.preventDefault();
        event.stopPropagation();
        $.each(allChecks, function(index, obj) {
          if( obj.is(':visible') ) {
            _toggleCollapseStatus(obj)
          }
        });
        _callAfterCollapseToggle();
      });

      // Each menu item keeps a list of elements to use
      $('.collapse_h2, .expand_h2').each(function(index, obj) {
        var self = $(obj);
        var mySections = [];
        // Regular expression to filter sections, considers pass/fail
        var pattern = new RegExp(self.data('section') + '(:\\w+)?$');
        $.each(allHeaders, function(index, obj) {
          if( pattern.test($(obj).text().trim()) ) {
            var nextDiv = $($(obj).next('div'));
            mySections.push(nextDiv);
          }
        });
        $.data(obj, 'mySections', mySections);
      });

      //Collapse h2
      $('.collapse_h2').click(function(event) {
        event.preventDefault();
        event.stopPropagation();
        var self = $(this);
        var mySections = self.data('mySections');

        $.each(mySections, function( index, obj) {
          if( obj.is(':visible') ) {
            _toggleCollapseStatus(obj);
          }
        });

        _callAfterCollapseToggle();
      });

      //Expand h2
      $('.expand_h2').click(function(event) {
        event.preventDefault();
        event.stopPropagation();

        var self = $(this);
        var mySections = self.data('mySections');
        $.each(mySections, function( index, obj) {
          if( ! obj.is(':visible') ) {
            _toggleCollapseStatus(obj);
          }
        });

        _callAfterCollapseToggle();
      });

      //Since javascript is active we can collapse sections and reveal the menu
      $('#collapse_menu').show();
    },
  };
});
