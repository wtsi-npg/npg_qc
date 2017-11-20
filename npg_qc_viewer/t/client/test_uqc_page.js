/* globals $, requirejs, QUnit, document */

"use strict";
requirejs.config({
  baseUrl: '../../root/static',
  paths: {
    'qunit': 'bower_components/qunit/qunit/qunit',
    jquery:  'bower_components/jquery/dist/jquery'
  }
});

requirejs(['scripts/qcoutcomes/qc_page', 'scripts/qcoutcomes/qc_outcomes_view'],
  function(qc_page, qc_outcomes_view) {
    QUnit.config.autostart = false;

    QUnit.test("Parsing run status", function (assert) {

      var title = qc_page._parseRunStatus('NPG SeqQC v64.1: Results for run 24169 (run 24169 status: run archived)');
      assert.equal(title.takenBy, null, 'Correctly sets -taken by- to null user');
      assert.equal(title.runStatus, 'run archived', 'Correctly identifies the page as "run archived"');

      title = qc_page._parseRunStatus('NPG SeqQC v64.1: Results for run 24169 (run 24169 status: qc complete)');
      assert.equal(title.takenBy, null, 'Correctly sets -taken by- to null user');
      assert.equal(title.runStatus, 'qc complete', 'Correctly identifies the page as "qc complete"');
    });

    QUnit.test("Valid pages for UQC annotation", function (assert) {
      var originalTitle = document.title;

      var emptyStrings = [ '', ' ' ];
      var funct = function() { qc_page.pageForQC(); };
      for ( var i = 0; i < emptyStrings.length; i++ ) {
        document.title = emptyStrings[i];
        assert.throws( funct,
                       /Error: page title is expected but not available in page/,
                       "Throws error when page has empty title" );
      }
      document.title = originalTitle;
      for ( i = 0; i < emptyStrings.length; i++ ) {
        $('#header h1 span.rfloat').text(emptyStrings[i]);
        assert.throws( funct, 
                       /Error: authentication data is expected but not available in page/,
                       "Throws error when authentication info is empty" );
      }

      $('#header h1 span.rfloat').text('Logged in as aa11 (mqc)');
      var titlesForUQCWrite = [
        'NPG SeqQC v0: Results for run 15000 (run 15000 status: qc complete)',
        'NPG SeqQC v0: Results for run 15000 (run 15000 status: run archived)',
        'NPG SeqQC v0: Results (all) for runs 15000 lanes 1 (run 15000 status: qc complete)',
        'NPG SeqQC v0: Results (all) for runs 15000 lanes 1 (run 15000 status: run archived)'
      ];

      for( i = 0; i < titlesForUQCWrite.length; i++ ) {
        document.title = titlesForUQCWrite[i];
        var pageForUQC = qc_page.pageForQC();
        assert.ok(pageForUQC.isPageForUQC, 'Page for utility QC write');
      }

      var titlesNotForUQCWrite = [
        "NPG SeqQC v0: Libraries: 'AA123456B' (run 23317 status: qc complete)",
        "NPG SeqQC v0: Sample '1234ABCD1234567' (run 15000 status: qc complete)",
        "NPG SeqQC v0: Pool NT1114915D (run 15000 status: qc complete)"
      ];

      for( i = 0; i < titlesNotForUQCWrite.length; i++ ) {
        document.title = titlesNotForUQCWrite[i];
        pageForUQC = qc_page.pageForQC();
        assert.ok(!pageForUQC.isPageForUQC, 'Pages other than run or lane Pages are not for Utility QC');
      }

      titlesNotForUQCWrite = [
        'NPG SeqQC v0: Results (all) for runs 16074 lanes 1 2 (run 16074 status: qc completed)',
        'NPG SeqQC v0: Results (all) for runs 16074 16075 lanes 1',
      ];
      for( i = 0; i < titlesNotForUQCWrite.length; i++ ) {
        document.title = titlesNotForUQCWrite[i];
        pageForUQC = qc_page.pageForQC();
        assert.ok(!pageForUQC.isPageForUQC, 'Pages with data for multiple runs/lanes are not for Utility QC');
      }

      document.title = 'NPG SeqQC v0: Results for run 15000 (run 15000 status: qc in progress, taken by aa11)';

      $('#header h1 span.rfloat').text('Logged in as aa11');
      pageForUQC = qc_page.pageForQC();
      assert.ok(!pageForUQC.isPageForUQC, 'Page is not for utility QC when user lacks reviewer role');

      $('#header h1 span.rfloat').text('Not logged in');
      pageForUQC = qc_page.pageForQC();
      assert.ok(!pageForUQC.isPageForUQC, 'Page is not for utility QC when no user is logged in');

      document.title = originalTitle;
    });

    QUnit.test("Run / Lane page", function (assert) {
      var originalTitle = document.title;

      document.title = 'NPG SeqQC v0: Results for run 15000 (run 15000 status: qc complete)';
      var pageForUQC = qc_page.pageForQC();
      assert.ok(pageForUQC.isRunPage, 'Page is correclty marked as run page');

      document.title = 'NPG SeqQC v0: Results (all) for runs 15000 lanes 1 (run 15000 status: run archived)';
      pageForUQC = qc_page.pageForQC();
      assert.ok(!pageForUQC.isRunPage, 'Page is correclty marked as not run page');

      document.title = "NPG SeqQC v0: Libraries: 'AA123456B'";
      pageForUQC = qc_page.pageForQC();
      assert.ok(!pageForUQC.isRunPage, 'Page is correclty marked as not run page');

      document.title = originalTitle;
    });

    QUnit.test("Clickable link UQC annotation", function (assert) {
      var nbAnnotationLinks = $(".uqcClickable").length;
      assert.equal(nbAnnotationLinks, 0, 'No preexisting annotationLink');
      var container = "#menu #links";
      qc_outcomes_view.addUQCAnnotationLink (container, null);
      nbAnnotationLinks = $(" .uqcClickable").length;
      assert.equal(nbAnnotationLinks, 1, 'Annotation Link present after call');
      nbAnnotationLinks = $(container + " .uqcClickable").length;
      assert.equal(nbAnnotationLinks, 1, 'Annotation Link is at the expected container');
      
      $('.uqcClickable').trigger('click');
      nbAnnotationLinks = $(".uqcClickable").length;
      assert.equal(nbAnnotationLinks, 0, 'Annotation Link is removed after clicking on it');
    });

    QUnit.test("Identifying uqc-able elements", function (assert) {

      var qcOutcomes = {"lib":{},
                        "uqc":{"18245:1":{"uqc_outcome":"Rejected"},
                               "18245:1:1":{"uqc_outcome":"Undecided"},
                               "18245:1:2":{"uqc_outcome":"Accepted"},
                               "19001:1":{"uqc_outcome":"Accepted"},},
                        "seq":{}};

      qc_outcomes_view.addUQCAnnotationLink("#menu #links > ul:eq(1)",
                                            function() {
                                              qc_outcomes_view.launchUtilityQCProcesses(true, qcOutcomes);
                                            });
      var nbOfMQCAbleElements = $(qc_outcomes_view.MQC_ABLE_CLASS).length;
      assert.equal(nbOfMQCAbleElements, 6, '6 markup present initially');
      $('.uqcClickable').trigger('click');
      

      var expectedColours = [
        qc_outcomes_view.COLOURS_RGB.RED,
        qc_outcomes_view.COLOURS_RGB.GREY,
        qc_outcomes_view.COLOURS_RGB.GREEN,
        qc_outcomes_view.COLOURS_RGB.GREEN,
        qc_outcomes_view.COLOURS_RGB.GREY,
        qc_outcomes_view.COLOURS_RGB.GREY,
      ];

      [
        "rpt_key\\3A 18245\\3A 1",
        "rpt_key\\3A 18245\\3A 1\\3A 1",
        "rpt_key\\3A 18245\\3A 1\\3A 2",
        "rpt_key\\3A 19001\\3A 1",
        "rpt_key\\3A 19001\\3A 1\\3A 1",
        "rpt_key\\3A 19001\\3A 1\\3A 2"
      ].forEach(function(targetId, index) {
        $('#' + targetId + ' .' + qc_outcomes_view.UQC_CONTROL_CLASS).each(function(i, element) {
          var $element = $(element);
          assert.ok(typeof $element.css("background-color") !== 'undefined');
          assert.equal(
            $element.css("background-color"),
            expectedColours[index],
            'expected colour found'
          );
        });
      });
       
      
    });

    QUnit.test("Passing a uqc_outcome to a non uqc-able element should not mark for UQC writing",
     function (assert) {
      var qcOutcomes = {"lib":{},
                        "uqc":{"19001:1":{"uqc_outcome":"Accepted"}},
                        "seq":{}};



      qc_outcomes_view.addUQCAnnotationLink("#menu #links > ul:eq(1)",
                                            function() {
                                              qc_outcomes_view.launchUtilityQCProcesses(true, qcOutcomes);
                                            });

      var nbOfMQCAbleElements = $(qc_outcomes_view.MQC_ABLE_CLASS).length;
      assert.equal(nbOfMQCAbleElements, 6, '6 MQC markup present initially');
 
      $("#rpt_key\\3A 19001\\3A 1 " + qc_outcomes_view.MQC_ABLE_CLASS).remove();
      nbOfMQCAbleElements = $(qc_outcomes_view.MQC_ABLE_CLASS).length;
      assert.equal(nbOfMQCAbleElements, 5, '5 MQC markup present after removing mark in 19001:1');

      $('.uqcClickable').click();
      var nbOfUQCMarkedElements = 0;
      $("#rpt_key\\3A 19001\\3A 1 ." + qc_outcomes_view.UQC_CONTROL_CLASS).each(function() {
        nbOfUQCMarkedElements++;
      });
      assert.equal(nbOfUQCMarkedElements, 0, '19001:1 is not UQC marked' );

      [
        "rpt_key\\3A 18245\\3A 1",
        "rpt_key\\3A 18245\\3A 1\\3A 1",
        "rpt_key\\3A 18245\\3A 1\\3A 2",
        "rpt_key\\3A 19001\\3A 1\\3A 1",
        "rpt_key\\3A 19001\\3A 1\\3A 2"
      ].forEach(function(targetId) {
        var targetIsMarked = ($('#' + targetId + ' .' + qc_outcomes_view.UQC_CONTROL_CLASS).length === 1);
        assert.ok(targetIsMarked,'UQC Mark is defined for key :' + targetId);
      });
       
    });
    

    QUnit.start();
  }
);
