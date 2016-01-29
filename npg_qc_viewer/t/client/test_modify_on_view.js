"use strict";
requirejs.config({
  baseUrl: '../../root/static',
  paths: {
    jquery: 'bower_components/jquery/dist/jquery',
  },
});

define(['scripts/modify_on_view',], function(disp_on_dem) {
  // run the tests.
  QUnit.test('Testing changing objects on window scroll', function (assert) {
    var $w = $(window);
    var elements = ['first', 'up', 'middle', 'down', 'last'];
    var threshold = $w.innerHeight() * 0.75;
    var elementsToDisplay = [];

    for (var i = 0; i < elements.length; i++) {
      var selectorFilter = '#' + elements[i];
      $($(selectorFilter).first()).data('displayed', 0);

      var element = disp_on_dem.buildModifyOnViewElement(
        selectorFilter,
        threshold,
        function (i, obj) { if (obj.data('displayed') !== 1) { obj.data('displayed', 1) } },
        function (i, obj) { if (obj.data('displayed') !== 0) { obj.data('displayed', 0) } }
      );

      elementsToDisplay.push(element);
    }

    disp_on_dem.modifyOnView(elementsToDisplay);

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

  QUnit.test('Testing changing objects on window scroll with a big DOM', function (assert) {
    var bigHtml = $('#big_padding_data').html();
    var howManyLanes = 100;

    var paddingNames = ['padding_at_start', 'padding_at_end'];
    for(var i = 0; i < paddingNames.length; i++) {
      var element = $($('#' + paddingNames[i]).first());
      for(var j = 0; j < howManyLanes; j++) {
        element.append(bigHtml);
      }
    }

    var paddingElementsInDOM = $('.results_full_lane').length;
    assert.equal(paddingElementsInDOM,
                 ( howManyLanes * 2 ) + 1,
                 'Generated ' + ( howManyLanes * 2 ) + ' extra padding elements in DOM');

    var $w = $(window);
    window.scroll(0, windowStartPos);
    $w.trigger("scroll");

    var elements = ['first', 'up', 'middle', 'down', 'last'];
    var threshold = $w.innerHeight() * 0.75;
    var elementsToDisplay = [];

    for (var i = 0; i < elements.length; i++) {
      var selectorFilter = '#' + elements[i];
      $($(selectorFilter).first()).data('displayed', 0);

      var element = disp_on_dem.buildModifyOnViewElement(
        selectorFilter,
        threshold,
        function (i, obj) { if (obj.data('displayed') !== 1) { obj.data('displayed', 1) } },
        function (i, obj) { if (obj.data('displayed') !== 0) { obj.data('displayed', 0) } }
      );

      elementsToDisplay.push(element);
    }

    disp_on_dem.modifyOnView(elementsToDisplay);

    var $first = $('#first').first();
    var $up = $('#up').first();
    var $middle = $('#middle').first();
    var $down = $('#down').first();
    var $last = $('#last').first();

    assert.equal($first.data('displayed'), 0, "first has not displayed");
    assert.equal($up.data('displayed'), 0, "up has not displayed");
    assert.equal($middle.data('displayed'), 0, "middle has not displayed");
    assert.equal($down.data('displayed'), 0, "down has not displayed");
    assert.equal($last.data('displayed'), 0, "last has not displayed");

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

    for(var i = 0; i < paddingNames.length; i++) {
      var element = $($('#' + paddingNames[i]).first());
      element.empty();
    }
  });

  QUnit.start();
});

