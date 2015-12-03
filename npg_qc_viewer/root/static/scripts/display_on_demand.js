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

  var buildDisplayOnViewElement = function (selectorFilter, threshold, displayFunction, removeFunction) {
    var config1 = {
      selectorFilter  : selectorFilter,
      threshold       : threshold,
      displayFunction : displayFunction,
      removeFunction  : removeFunction
    };
    return config1;
  };

  var displayOnView = function (elements) {
    $(window).on('scroll resize lookup', function() {
      for (var j = 0; j < elements.length; j++) {
        var config = elements[j];
        var threshold = config.threshold;
        var $w = $(window);
        var wt = $w.scrollTop() - threshold;
        var viewHeight = $w.height() + (2 * threshold);

        $(config.selectorFilter).each(function (i, obj) {
          var self = $(this);
          var selfTop = self.offset().top;

          if ( overlap( wt, viewHeight, selfTop, self.height() ) ) {
            if (self.data('inView') === undefined || self.data('inView') == 0) {
              window.console.log("Building plots " + i);
              self.data('inView', 1);
              config.displayFunction(i, self);
            }
          } else {
            if (self.data('inView') == 1) {
              window.console.log("Destroying plots " + i);
              self.data('inView', 0);
              config.removeFunction(i, self);
            }
          }
        });
      }
    });
  };

  return {
    overlap : overlap,
    buildDisplayOnViewElement : buildDisplayOnViewElement,
    displayOnView : displayOnView,
  };
});

