/*
 *
 *
 * Example:
 *
 *
 *
 *
 *
 */
define(['jquery'], function (jQuery) {

  var overlap = function (start1, height1, start2, height2) {
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

  var buildDisplayOnViewElement = function (selectorFilter, threshold, displayCallback, removeCallback) {
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

  var displayOnView = function (elements, verbose) {
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
    buildDisplayOnViewElement : buildDisplayOnViewElement,
    displayOnView : displayOnView,
  };
});

