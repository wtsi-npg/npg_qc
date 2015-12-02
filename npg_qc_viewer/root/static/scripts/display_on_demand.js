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
  }

  return {
    overlap : overlap,
  };
});

