"use strict";
requirejs.config({
  baseUrl: '../',
  paths: {
    jquery: 'bower_components/jquery/dist/jquery',
  },
});

define(['scripts/display_on_demand',], function(disp_on_dem) {
    // run the tests.
    QUnit.test('Testing changing objects on window scroll', function (assert) {
      var $w = $(window);
      var elements = ['first', 'up', 'middle', 'down', 'last'];
      var threshold = $w.innerHeight() * 0.75;
      var elementsToDisplay = [];

      for (var i = 0; i < elements.length; i++) {
        var selectorFilter = '#' + elements[i];
        $($(selectorFilter).first()).data('displayed', 0);

        var element = disp_on_dem.buildDisplayOnViewElement(
          selectorFilter,
          threshold,
          function (i, obj) { obj.data('displayed', 1) },
          function (i, obj) { obj.data('displayed', 0) }
        );

        elementsToDisplay.push(element);
      }

      disp_on_dem.displayOnView(elementsToDisplay);

      var $first = $('#first').first();
      var $up = $('#up').first();
      var $middle = $('#middle').first();
      var $down = $('#down').first();
      var $last = $('#last').first();

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
      assert.equal($first.data('displayed'), 1, "first has displayed");
      assert.equal($up.data('displayed'), 0, "up has not displayed");
      assert.equal($middle.data('displayed'), 0, "middle has not displayed");
      assert.equal($down.data('displayed'), 0, "down has not displayed");
      assert.equal($last.data('displayed'), 0, "last has not displayed");

      window.scroll(0, $up.offset().top) - 10;
      $w.trigger("scroll");
      assert.equal($first.data('displayed'), 0, "first has not displayed");
      assert.equal($up.data('displayed'), 1, "up has displayed");
      assert.equal($middle.data('displayed'), 0, "middle has not displayed");
      assert.equal($down.data('displayed'), 0, "down has not displayed");
      assert.equal($last.data('displayed'), 0, "last has not displayed");

      window.scroll(0, $middle.offset().top) - 10;
      $w.trigger("scroll");
      assert.equal($first.data('displayed'), 0, "first has not displayed");
      assert.equal($up.data('displayed'), 0, "up has not displayed");
      assert.equal($middle.data('displayed'), 1, "middle has displayed");
      assert.equal($down.data('displayed'), 1, "down has displayed");
      assert.equal($last.data('displayed'), 0, "last has not displayed");

      window.scroll(0, $down.offset().top) - 10;
      $w.trigger("scroll");
      assert.equal($first.data('displayed'), 0, "first has not displayed");
      assert.equal($up.data('displayed'), 0, "up has not displayed");
      assert.equal($middle.data('displayed'), 1, "middle has displayed");
      assert.equal($down.data('displayed'), 1, "down has displayed");
      assert.equal($last.data('displayed'), 1, "last has displayed");

      window.scroll(0, $up.offset().top) - 10;
      $w.trigger("scroll");
      assert.equal($first.data('displayed'), 0, "first has not displayed");
      assert.equal($up.data('displayed'), 1, "up has displayed");
      assert.equal($middle.data('displayed'), 0, "middle has not displayed");
      assert.equal($down.data('displayed'), 0, "down has not displayed");
      assert.equal($last.data('displayed'), 0, "last has not displayed");

      window.scroll(0, $first.offset().top - 10);
      $w.trigger("scroll");
      assert.equal($first.data('displayed'), 1, "first has displayed");
      assert.equal($up.data('displayed'), 0, "up has not displayed");
      assert.equal($middle.data('displayed'), 0, "middle has not displayed");
      assert.equal($down.data('displayed'), 0, "down has not displayed");
      assert.equal($last.data('displayed'), 0, "last has not displayed");

    });
    QUnit.start();
  }
);

