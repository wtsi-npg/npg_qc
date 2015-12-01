"use strict";
requirejs.config({
  baseUrl: '../',
  paths: {
    jquery: 'bower_components/jquery/dist/jquery',
  },
});

define(["jquery"],
  function($) {
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

    $(window).on("scroll resize lookup", function () {
      var self = $(this);
      var threshold = self.innerHeight() * 0.75;
      var wt = self.scrollTop() - threshold, wh = ( self.innerHeight() + ( 2 * threshold ) );

      var elements = ['first', 'up', 'middle', 'down', 'last'];
      for (var i = 0; i < elements.length; i++) {
        var element = $($('#' + elements[i]).first());
        var fromTop = element.offset().top;
        if (overlap(wt, wh, fromTop, element.height() )) {
          if ( element.data('inView') == 0 ) {
            element.data('inView', 1);
          }
        } else {
          element.data('inView', 0);
        }
      }
    });

    // run the tests.
    QUnit.test('Testing changing object on window scroll', function (assert) {
      var $w = $(window);
      var $first = $('#first').first(); $first.data('inView', 0);
      var $up = $('#up').first(); $up.data('inView', 0);
      var $middle = $('#middle').first(); $middle.data('inView', 0);
      var $down = $('#down').first(); $down.data('inView', 0);
      var $last = $('#last').first(); $last.data('inView', 0);

      var windowHeight = $w.innerHeight();
      $(".padding_long").each(function () {
        var self = $(this);
        self.height(windowHeight * 2);
      });
      $(".padding_med").each(function () {
        var self = $(this);
        self.height(windowHeight * 1.5);
      });
      $(".padding_short").each(function () {
        var self = $(this);
        self.height(windowHeight / 2);
      });

      var windowStartPos = $first.offset().top - 10;
      window.scroll(0, windowStartPos);
      $w.trigger("scroll");
      assert.equal($first.data('inView'), 1, "first has inView");
      assert.equal($up.data('inView'), 0, "up has not inView");
      assert.equal($middle.data('inView'), 0, "middle has not inView");
      assert.equal($down.data('inView'), 0, "down has not inView");
      assert.equal($last.data('inView'), 0, "last has not inView");
      
      window.scroll(0, $up.offset().top) - 10;
      $w.trigger("scroll");
      assert.equal($first.data('inView'), 0, "first has not inView");
      assert.equal($up.data('inView'), 1, "up has inView");
      assert.equal($middle.data('inView'), 0, "middle has not inView");
      assert.equal($down.data('inView'), 0, "down has not inView");
      assert.equal($last.data('inView'), 0, "last has not inView");

      window.scroll(0, $middle.offset().top) - 10;
      $w.trigger("scroll");
      assert.equal($first.data('inView'), 0, "first has not inView");
      assert.equal($up.data('inView'), 0, "up has not inView");
      assert.equal($middle.data('inView'), 1, "middle has inView");
      assert.equal($down.data('inView'), 1, "down has inView");
      assert.equal($last.data('inView'), 0, "last has not inView");

      window.scroll(0, $down.offset().top) - 10;
      $w.trigger("scroll");
      assert.equal($first.data('inView'), 0, "first has not inView");
      assert.equal($up.data('inView'), 0, "up has not inView");
      assert.equal($middle.data('inView'), 1, "middle has inView");
      assert.equal($down.data('inView'), 1, "down has inView");
      assert.equal($last.data('inView'), 1, "last has inView");

      window.scroll(0, $up.offset().top) - 10;
      $w.trigger("scroll");
      assert.equal($first.data('inView'), 0, "first has not inView");
      assert.equal($up.data('inView'), 1, "up has inView");
      assert.equal($middle.data('inView'), 0, "middle has not inView");
      assert.equal($down.data('inView'), 0, "down has not inView");
      assert.equal($last.data('inView'), 0, "last has not inView");

      window.scroll(0, $first.offset().top - 10);
      $w.trigger("scroll");
      assert.equal($first.data('inView'), 1, "first has inView");
      assert.equal($up.data('inView'), 0, "up has not inView");
      assert.equal($middle.data('inView'), 0, "middle has not inView");
      assert.equal($down.data('inView'), 0, "down has not inView");
      assert.equal($last.data('inView'), 0, "last has not inView");

    });
    QUnit.start();
  }
);

