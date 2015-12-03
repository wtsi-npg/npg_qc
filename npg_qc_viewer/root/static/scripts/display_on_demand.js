/*
 *
 * Functionality to display and remove objects from DOM as they come into/leave
 * view.
 *
 *
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
 *     function (i, obj) { callSomething(i, obj); },
 *     function (i, obj) { return; } // Do nothing extra
 *   );
 *
 *   var allElements = [smallPlots, bigPlot];
 *   displayOnView(allElements);
 *
 */
define(['jquery'], function (jQuery) {
  var overlap = function (start1, height1, start2, height2) {
    if(typeof(start1) === "undefined" || start1 == null) {
      throw new TypeError("First element start position can not be undefined");
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
    displayCallback = typeof displayCallback !== 'undefined' ? displayCallback : function (i, obj) { };
    removeCallback = typeof removeCallback !== 'undefined' ? removeCallback : function (i, obj) { };

    var element = {
      selectorFilter  : selectorFilter,
      threshold       : threshold,
      displayCallback : displayCallback,
      removeCallback  : removeCallback
    };

    return element;
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
        var wt = $w.scrollTop() - threshold;
        var viewHeight = $w.height() + (2 * threshold);

        $(element.selectorFilter).each(function (i, obj) {
          var self = $(this);
          var selfTop = self.offset().top;

          if ( overlap( wt, viewHeight, selfTop, self.height() ) ) {
            if (self.data('display_on_view_inView') === undefined || self.data('display_on_view_inView') == 0) {
              verbose && window.console && window.console.log("Displaying " + i);
              self.data('display_on_view_inView', 1);
              element.displayCallback(i, self);
            }
          } else {
            if (self.data('display_on_view_inView') == 1) {
              verbose && window.console && window.console.log("Displaying " + i);
              self.data('display_on_view_inView', 0);
              element.removeCallback(i, self);
            }
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

