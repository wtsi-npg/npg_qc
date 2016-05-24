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

    var isVisible = function( element ) {
      return $($(element)).is(':visible');
    };

    QUnit.test('Checking pre-reqs', function(assert) {
      assert.ok( isVisible(allResults) , 'Main container visible' );
    });

    QUnit.test('Testing page after collapser init', function( assert ) {
      collapse.init();
      var $allResults = $($(allResults));

      assert.ok($allResults.is(':visible'), 'Main container is visible');
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
      assert.ok( isVisible(referenceTitle) , 'Rereference title is visible' );
      $.each(allChecksContent, function( index, value ) {
        assert.ok( !isVisible(value) , 'Check is not visible' );
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
      assert.ok( !isVisible(adapterContent), 'Expected content not visible' );

      $(adapterTitle).trigger('click'); // To expand
      allVisible.push(adapterContent);
      allOpen.push(adapterTitle);
      $.each( allVisible, function( index, value ) {
        assert.ok( isVisible(value), 'Expected visible' );
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

      $(adapterTitle).trigger('click'); // To collapse
      $(insertSizeTitle).trigger('click'); // To collapse

      assert.ok( !isVisible(adapterContent), 'Expected check 1 content not visible' );
      assert.ok( !isVisible(insertSizeContent), 'Check 2 content is not visible')

      $(adapterTitle).trigger('click'); // To expand

      assert.ok( isVisible(adapterContent), 'Expected check 1 content is visible' );
      assert.ok( !isVisible(insertSizeContent), 'Check 2 content is not visible')
    });

    QUnit.test('Calling collapse/expand all', function( assert ) {
      collapse.init();
      var alwaysVisible = [ runTitle, allResults, referenceTitle, adapterTitle,
                         insertSizeTitle ];
      var togglingSections = [ adapterContent, insertSizeContent ];

      $.each( alwaysVisible, function( index, value ) {
        assert.ok( isVisible(value), 'Expected visible <always visible for this test>' );
      });
      $.each( togglingSections, function( index, value ) {
        assert.ok( isVisible(value), 'Expected visible' );
      });

      $('#collapse_all_results').trigger('click'); //To collapse all results

      $.each( alwaysVisible, function( index, value ) {
        assert.ok( isVisible(value), 'Expected visible because they not collapse' );
      });
      $.each( togglingSections, function( index, value ) {
        assert.ok( !isVisible(value), 'Expected not visible after collapse all' );
      });

      $('#expand_all_results').trigger('click'); //To expand all results

      $.each( alwaysVisible, function( index, value ) {
        assert.ok( isVisible(value), 'Expected visible because they not collapse' );
      });
      $.each( togglingSections, function( index, value ) {
        assert.ok( isVisible(value), 'Expected visible after expand all' );
      });
    });

    QUnit.test('Calling collapse all adapters', function( assert ) {
      collapse.init();
      var alwaysVisible = [ runTitle, allResults, referenceTitle, adapterTitle,
                         insertSizeTitle, insertSizeContent ];
      var togglingSections = [ adapterContent ];

      $.each( alwaysVisible, function( index, value ) {
        assert.ok( isVisible(value), 'Expected visible <always visible for this test>' );
      });
      $.each( togglingSections, function( index, value ) {
        assert.ok( isVisible(value), 'Expected visible <adapter>' );
      });

      $('#collapse_all_adapter').trigger('click'); //To collapse adapter

      $.each( alwaysVisible, function( index, value ) {
        assert.ok( isVisible(value), 'Expected visible because they not collapse, only adapter' );
      });
      $.each( togglingSections, function( index, value ) {
        assert.ok( !isVisible(value), 'Expected not visible after collapse adapter' );
      });

      $('#collapse_all_insert_size').trigger('click');
      assert.ok( !isVisible(insertSizeContent), 'Collapsed all insert size' );
      $.each( togglingSections, function( index, value ) {
        assert.ok( !isVisible(value), 'Expected not visible adapter' );
      });
      $('#expand_all_insert_size').trigger('click');
      assert.ok( isVisible(insertSizeContent), 'Exapanded all insert size' );
      $.each( togglingSections, function( index, value ) {
        assert.ok( !isVisible(value), 'Expected not visible adapter' );
      });

      $('#expand_all_adapter').trigger('click'); //To expand adapter

      $.each( alwaysVisible, function( index, value ) {
        assert.ok( isVisible(value), 'Expected visible because they did not collapse' );
      });
      $.each( togglingSections, function( index, value ) {
        assert.ok( isVisible(value), 'Expected visible after expand adapter' );
      });
    });

    // run the tests.
    QUnit.start();
  }
);
