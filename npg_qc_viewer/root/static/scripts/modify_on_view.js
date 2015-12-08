/*
 *
 * Functionality to modify DOM objects when they come into view. It works by
 * adding an event listener to the window. Events which change the portion of
 * the page in view range fire operations on objects of interest.
 *
 * The function requires a list of configurations. One for each kind of object
 * to operate on. Each configuration can be build using the builder function
 * provided. This function takes 4 arguments,
 *   - jquery selector filter string to find the objects in the page
 *   - threshold to path both extremes of the window so elements can be
 *     pre-processed before they come into view
 *   - call back to function to call when the object comes into view
 *   - call back to function to call when object leaves the view
 *
 * The callback functions can be used to generate or remove content from the
 * object being operated on. Both functions get the index and object retrieved
 * when iterating the result of using the jQuery selector.
 *
 * Example:
 *
 *   var smallPlots = buildModifyOnViewElement(
 *     '.small_plots',
 *     100,
 *     function (i, obj) { callSomething(i, obj); },
 *     function (i, obj) { callSomethingElse(i, obj); }
 *   );
 *
 *   var bigPlot = buildModifyOnViewElement(
 *     '#big_plot',
 *     1000,
 *     function (i, obj) { doSomethingWith(obj); },
 *     function (i, obj) { return; } // Do nothing extra
 *   );
 *
 *   var medPlot = buildModifyOnViewElement(
 *     '#med_plot',
 *     500,
 *     null,
 *     function (i, obj) { doSomethingWith(obj); },
 *   );
 *
 *   displayOnView([smallPlots, bigPlot, medPlot]);
 *
 */
/* globals $: false, window: false, define: false */
/* jshint -W030, -W083 */
'use strict';
define(['jquery'], function () {
  var overlap = function (start1, height1, start2, height2) {
    if(typeof(start1) === "undefined" || start1 == null) {
      throw new TypeError("First element start position cannot be undefined");
    }
    if(typeof(height1) === "undefined" || height1 == null) {
      throw new TypeError("First element height can not be undefined");
    }
    if(typeof(start2) === "undefined" || start2 == null) {
      throw new TypeError("Second element start position can not be undefined");
    }
    if(typeof(height2) === "undefined" || height2 == null) {
      throw new TypeError("Second element height can not be undefined");
    }

    var o1s, o1e, o2s, o2e;
    if ( height1 >= height2 ) {
      o1s = start1; o1e = start1 + height1;
      o2s = start2; o2e = start2 + height2;
    } else {
      o1s = start2; o1e = start2 + height2;
      o2s = start1; o2e = start1 + height1;
    }

    return ( (o2s >= o1s && o2s <= o1e) || (o2e >= o1s && o2e <= o1e) );
  };

  var buildModifyOnViewElement = function (selectorFilter, threshold, displayCallback, removeCallback) {
    if(typeof(selectorFilter) === "undefined" || selectorFilter == null) {
      throw new TypeError("selectorFilter can not be undefined");
    }

    threshold = typeof threshold !== 'undefined' ? threshold : 0;
    displayCallback = typeof displayCallback !== 'undefined' ? displayCallback : function () { };
    removeCallback = typeof removeCallback !== 'undefined' ? removeCallback : function () { };

    var composite = {
      selectorFilter  : selectorFilter,
      threshold       : threshold,
      displayCallback : displayCallback,
      removeCallback  : removeCallback
    };

    return composite;
  };

  var modifyOnView = function (elements, verbose) {
    if(typeof(elements) === "undefined" || elements == null) {
      throw new TypeError("elements can not be undefined");
    }
    if( !Array.isArray(elements) ) {
      throw new TypeError("elements must be an array");
    }

    verbose = typeof verbose !== 'undefined' ?  verbose : false;

    $(window).on('scroll resize lookup', function() {
      for (var j = 0; j < elements.length; j++) {
        var element = elements[j];
        var threshold = element.threshold;
        var $w = $(window);
        var viewTop = $w.scrollTop() - threshold;
        var viewHeight = $w.height() + (2 * threshold);

        $(element.selectorFilter).each(function (i, obj) {
          obj = $(obj);
          var objTop = obj.offset().top;

          if ( overlap( viewTop, viewHeight, objTop, obj.height() ) ) {
            verbose && window.console && window.console.log("Element in view " + i);
            element.displayCallback(i, obj);
          } else {
            verbose && window.console && window.console.log("Element out of view " + i);
            element.removeCallback(i, obj);
          }
        });
      }
    });
  };

  return {
    buildModifyOnViewElement : buildModifyOnViewElement,
    modifyOnView : modifyOnView,
  };
});

