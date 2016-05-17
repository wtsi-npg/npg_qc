/* globals $, requirejs, QUnit */
"use strict";
requirejs.config({
  baseUrl: '../../root/static',
  paths: {
    'qunit': 'bower_components/qunit/qunit/qunit',
    jquery: 'bower_components/jquery/dist/jquery',
  },
});

requirejs([
  'scripts/collapse'
], function(
  collapse
) {
    QUnit.config.autostart = false;

    var allResults       = '#all_results';
    var runTitle         = '#run_title';
    var adapterTitle     = '#adapter_title';
    var insertSizeTitle  = '#insert_size_title';
    var referenceTitle   = '#reference_title';

    var collapserClass  = 'collapser';
    var collapserOpen   = 'collapser_open';
    var collapserClosed = 'collapser_closed';

    var adapterContent    = '#adapter_content';
    var insertSizeContent = '#insert_size_content';

    var allCollapsible      = [ runTitle, adapterTitle, insertSizeTitle ];
    var allCollapsibleNames = [ 'run title', 'check 1', 'check 2'];

    var allChecksContent = [ adapterContent, insertSizeContent ];

    var isOpen = function( element ) {
      var $element = $($(element));
      return $element.hasClass(collapserOpen) && !$element.hasClass(collapserClosed);
    };

    var isClosed = function( element ) {
      var $element = $($(element));
      return $element.hasClass(collapserClosed) && !$element.hasClass(collapserOpen);
    };

    var isVisible = function( element ) {
      return $($(element)).is(':visible');
    };

    QUnit.test('Checking pre-reqs', function(assert) {
      assert.ok( isVisible(allResults) , 'Main container visible' );
      $.each(allCollapsible, function( index, value ) {
        assert.ok($($(value)).hasClass(collapserClass), 'Element <' +
                                                        allCollapsibleNames[index] +
                                                        '> has collapse class' );
      });
    });

    QUnit.test('Testing page after collapser init', function( assert ) {
      collapse.init();
      var $allResults = $($(allResults));

      assert.ok($allResults.is(':visible'), 'Main container is visible');
      assert.notOk($allResults.hasClass(collapserOpen), 'Main container not modified');
      assert.notOk(
        $($(reference_title)).hasClass(collapserOpen), 'Reference title not modified'
      );

      $.each(allCollapsible, function( index, value ) {
        assert.ok( isOpen( $($(value)) ), 'Element <' +
                                        allCollapsibleNames[index] +
                                        '> is open' );
      });
      assert.ok(
        isVisible(referenceTitle), 'Element <reference title> is visible'
      );
    });

    QUnit.test('Calling collapse in the run title', function( assert ) {
      collapse.init();
      assert.ok( isVisible(runTitle) , 'Run title is visible' );
      assert.ok( isVisible(allResults) , 'Main container is visible' );
      assert.ok( isVisible(referenceTitle) , 'Rereference title is visible' );
      $.each(allChecksContent, function( index, value ) {
        assert.ok( isVisible(value) , 'Check is visible' );
      });

      $(runTitle).trigger('click'); // To collapse
      assert.ok( isVisible(runTitle) , 'Run title is visible' );
      assert.ok( isVisible(allResults) , 'Main container is visible' );
      assert.notOk( isVisible(referenceTitle) , 'Rereference title is not visible' );
      $.each(allChecksContent, function( index, value ) {
        assert.notOk( isVisible(value) , 'Check is not visible' );
      });

      $(runTitle).trigger('click'); //To expand
      assert.ok( isVisible(runTitle) , 'Run title is visible' );
      assert.ok( isVisible(allResults) , 'Main container is visible' );
      assert.ok( isVisible(referenceTitle) , 'Rereference title is visible' );
      $.each(allChecksContent, function( index, value ) {
        assert.ok( isVisible(value) , 'Check is back to visible' );
      });
    });

    QUnit.test('Calling collapse in individual check', function( assert ) {
      collapse.init();
      assert.ok( isVisible(runTitle) , 'Run title is visible' );
      assert.ok( isVisible(allResults) , 'Main container is visible' );
      assert.ok( isVisible(referenceTitle) , 'Rereference title is visible' );
      $.each(allChecksContent, function( index, value ) {
        assert.ok( isVisible(value) , 'Check is visible' );
      });

      var allVisible = [ runTitle, allResults, referenceTitle, adapterTitle,
                         insertSizeTitle, insertSizeContent ];
      var allOpen    = [ runTitle, insertSizeTitle ];

      $(adapterTitle).trigger('click'); // To collapse
      $.each( allVisible, function( index, value ) {
        assert.ok( isVisible(value), 'Expected visible' );
      });
      $.each( allOpen, function( index, value ) {
        assert.ok( isOpen(value), 'Expected open' );
      });
      assert.notOk( isVisible(adapterContent), 'Expected content not visible' );
      assert.ok( isClosed(adapterTitle), 'Check 1 is closed' );

      $(adapterTitle).trigger('click'); // To expand
      allVisible.push(adapterContent);
      allOpen.push(adapterTitle);
      $.each( allVisible, function( index, value ) {
        assert.ok( isVisible(value), 'Expected visible' );
      });
      $.each( allOpen, function( index, value ) {
        assert.ok( isOpen(value), 'Expected open' );
      });
    });

    QUnit.test('Calling collapse/expand affect individual elements', function( assert ) {
      collapse.init();

      var allVisible = [ runTitle, allResults, referenceTitle, adapterTitle,
                         insertSizeTitle ];
      var allOpen    = [ runTitle, adapterTitle, insertSizeTitle ];

      $.each( allVisible, function( index, value ) {
        assert.ok( isVisible(value), 'Expected visible' );
      });
      $.each( allOpen, function( index, value ) {
        assert.ok( isOpen(value), 'Expected open' );
      });

      $(adapterTitle).trigger('click'); // To collapse
      $(insertSizeTitle).trigger('click'); // To collapse

      assert.ok( isOpen(runTitle), 'Expected run title open' );
      assert.ok( isClosed(adapterTitle), 'Expected check 1 closed' );
      assert.notOk( isVisible(adapterContent), 'Expected check 1 content not visible' );
      assert.ok( isClosed(insertSizeTitle), 'Expected check 2 closed' );
      assert.notOk( isVisible(insertSizeContent), 'Check 2 content is not visible')

      $(adapterTitle).trigger('click'); // To expand

      assert.ok( isOpen(runTitle), 'Expected run title open' );
      assert.ok( isOpen(adapterTitle), 'Expected check 1 open' );
      assert.ok( isVisible(adapterContent), 'Expected check 1 content is visible' );
      assert.ok( isClosed(insertSizeTitle), 'Expected check 2 closed' );
      assert.notOk( isVisible(insertSizeContent), 'Check 2 content is not visible')
    });

    // run the tests.
    QUnit.start();
  }
);
