/* globals $, requirejs, QUnit, document */
/* jshint -W083 */

"use strict";
requirejs.config({
  baseUrl: '../../root/static',
  paths: {
    'qunit': 'bower_components/qunit/qunit/qunit',
    jquery:  'bower_components/jquery/dist/jquery'
  }
});

requirejs([
  'scripts/qcoutcomes/manual_qc',
  'scripts/qcoutcomes/qc_page',
  'scripts/qcoutcomes/qc_outcomes_view',
  'scripts/qcoutcomes/qc_utils',
  '../../t/client/test_fixtures'
], function(
  NPG,
  qc_page,
  qc_outcomes_view,
  qc_utils,
  fixtures
) {
    var TestConfiguration = (function() {
      function TestConfiguration () {
      }

      TestConfiguration.prototype.getRoot = function() {
        return './';
      };

      return TestConfiguration;
    }) ();
    NPG.QC.ProdConfiguration = TestConfiguration;

    var initialAjax = $.ajax;
    var initialTitle = $('title').text();

    var runAsIfMain = function () {
      var qcp = qc_page.pageForQC();
      var callAfterGettingOutcomes = qcp.isPageForMQC ? function (data) {
                                                          NPG.QC.launchManualQCProcesses(qcp.isRunPage, data, '/qcoutcomes');
                                                        }
                                                      : null;
      qc_outcomes_view.fetchAndProcessQC('results_summary', '/qcoutcomes', callAfterGettingOutcomes);
    };

    QUnit.config.autostart = false;

    QUnit.test("Template", function (assert) {
      assert.expect(1);
      //Set fixtures
      var page_fixture = fixtures.fixtures_dont_display;
      $('#qunit-fixture').html(page_fixture);
      //Set return ajax call
      try {
        assert.ok(true, 'Is ok');
      } catch (err) {
        console.log(err);
      } finally {
        $.ajax = initialAjax;
        $('title').text(initialTitle);
      }
    });

    QUnit.test("Display sequencing manual qc", function ( assert ) {
      assert.expect(31);
      //Set title
      document.title = 'NPG SeqQC v0: Results for run 18000 (run 18000 status: qc in progress, taken by aa11)';
      //Set fixtures
      var page_fixture = fixtures.fixtures_seq_display;
      $('#qunit-fixture').html(page_fixture);
      //Set return ajax call

      $.ajax = function (options) {
        var data = {
          "lib":{ },
          "seq":{ "18000:1":{ "mqc_outcome":qc_utils.OUTCOMES.REJECTED_PRELIMINARY, "position":1, "id_run":18000 },
                  "18000:2":{ "mqc_outcome":qc_utils.OUTCOMES.ACCEPTED_PRELIMINARY, "position":2, "id_run":18000 },
                  "18000:3":{ "mqc_outcome":qc_utils.OUTCOMES.UNDECIDED, "position":3, "id_run":18000 }, },
          "uqc":{}       
        };
        options.success = function (callback) {
          callback(data, 'success', {});
          return options;
        };
        options.error = function () { return options; };
        return options;
      };

      try {
        runAsIfMain();
        var allNotChecked = [
          "#radio_rpt_key\\3A 18000\\3A 1_Accepted\\20 preliminary",
          "#radio_rpt_key\\3A 18000\\3A 1_Undecided",
          "#radio_rpt_key\\3A 18000\\3A 2_Rejected\\20 preliminary",
          "#radio_rpt_key\\3A 18000\\3A 2_Undecided",
          "#radio_rpt_key\\3A 18000\\3A 3_Accepted\\20 preliminary",
          "#radio_rpt_key\\3A 18000\\3A 3_Rejected\\20 preliminary",
          "#radio_rpt_key\\3A 18000\\3A 4_Accepted\\20 preliminary",
          "#radio_rpt_key\\3A 18000\\3A 4_Rejected\\20 preliminary",
          "#radio_rpt_key\\3A 18000\\3A 4_Undecided",
        ];
        for ( var i = 0; i < allNotChecked.length; i++ ) {
          var notCheckedSelector = allNotChecked[i];
          var notCheckedControl = $(notCheckedSelector);
          assert.notEqual(notCheckedControl.attr('checked'), 'checked', 'Control is not checked as per ajax qcoutcomes call');
        }

        var allChecked = [
          "#radio_rpt_key\\3A 18000\\3A 1_Rejected\\20 preliminary",
          "#radio_rpt_key\\3A 18000\\3A 2_Accepted\\20 preliminary",
          "#radio_rpt_key\\3A 18000\\3A 3_Undecided",
        ];
        for ( i = 0; i < allChecked.length; i++ ) {
          var checkedSelector = allChecked[i];
          var checkedControl = $(checkedSelector);
          assert.equal(checkedControl.attr('checked'), 'checked', 'Control is checked as per ajax qcoutcomes call');
        }

        var lanes = [ 1, 2, 3, 4 ];
        for ( i = 0; i < lanes.length; i++ ) {
          var workingContainerSelector = "#rpt_key\\3a 18000\\3a " +
                                         lanes[i] +
                                         " > td.lane.nbsp.td_mqc > span > span.lane_mqc_working";
          var workingContainerControl = $(workingContainerSelector);
          assert.equal(workingContainerControl.length, 1, 'Has a working icon container for lane ' + lanes[i]);
          assert.equal(workingContainerControl.children().length, 0, 'Working icon container is empty for lane ' + lanes[i]);

          var placeholder = $( "#rpt_key\\3A 18000\\3a " + lanes[i] + " > td.lane.nbsp.td_mqc > span" );
          assert.equal(placeholder.attr('style'),
                       'padding-right: 5px; padding-left: 10px;',
                       "Correct style for lane " + lanes[i] + " control's span");
        }

        var control = $("#radio_rpt_key\\3A 18000\\3A 1_Accepted\\20 preliminary");
        assert.equal(control.attr('value'), 'Accepted preliminary', 'Correct value for Accepted preliminary control');
        control = $("#radio_rpt_key\\3A 18000\\3A 1_Rejected\\20 preliminary");
        assert.equal(control.attr('value'), 'Rejected preliminary', 'Correct value for Rejected preliminary control');
        control = $("#radio_rpt_key\\3A 18000\\3A 1_Undecided");
        assert.equal(control.attr('value'), 'Undecided', 'Correct value for Undecided control');

        assert.ok($("#rpt_key\\3a 18000\\3a 1 > td.lane.nbsp.td_mqc > span > span.lane_mqc_button.lane_mqc_save").is(":visible"),
                     'Lane 1 with save button visible');
        assert.ok($("#rpt_key\\3a 18000\\3a 2 > td.lane.nbsp.td_mqc > span > span.lane_mqc_button.lane_mqc_save").is(":visible"),
                     'Lane 2 with save button visible');
        assert.notOk($("#rpt_key\\3a 18000\\3a 3 > td.lane.nbsp.td_mqc > span > span.lane_mqc_button.lane_mqc_save").is(":visible"),
                     'Lane 3 with save button hidden');
        assert.notOk($("#rpt_key\\3a 18000\\3a 4 > td.lane.nbsp.td_mqc > span > span.lane_mqc_button.lane_mqc_save").is(":visible"),
                     'Lane 4 with save button hidden');
      } catch (err) {
        console.log(err);
      } finally {
        $.ajax = initialAjax;
        $('title').text(initialTitle);
      }
    });

    QUnit.test("Display sequencing manual qc lane 1 is already final, lane 2 is accepted preliminary", function ( assert ) {
      assert.expect(15);
      //Set title
      document.title = 'NPG SeqQC v0: Results for run 18000 (run 18000 status: qc in progress, taken by aa11)';
      //Set fixtures
      var page_fixture = fixtures.fixtures_seq_mixed;
      $('#qunit-fixture').html(page_fixture);
      //Set return ajax call

      $.ajax = function (options) {
        var data = {
          "lib":{ },
          "seq":{ "18000:1":{ "mqc_outcome":qc_utils.OUTCOMES.ACCEPTED_FINAL, "position":1, "id_run":18000 },
                  "18000:2":{ "mqc_outcome":qc_utils.OUTCOMES.ACCEPTED_PRELIMINARY, "position":2, "id_run":18000 } },
          "uqc":{}        
        };
        options.success = function (callback) {
          callback(data, 'success', {});
          return options;
        };
        options.error = function () { return options; };
        return options;
      };

      try {
        runAsIfMain();
        var control = $("#rpt_key\\3a 18000\\3a 1 > td.lane.nbsp.qc_outcome_accepted_final");
        assert.equal(control.length, 1, "There is a td showing the accepted final for lane 1");
        control = $("#rpt_key\\3a 18000\\3a 1 > td.lane.nbsp.qc_outcome_accepted_final > span");
        assert.equal(control.length, 1, 'There is a container for the controls for lane 1');
        assert.equal(control.children().length, 0, "Span for mqc controls is empty in lane 1");
        assert.equal(control.attr('style'), undefined, 'No style for container in lane 1');
        control = $("#rpt_key\\3a 18000\\3a 1 > td.lane.nbsp.td_mqc > span > span.lane_mqc_working");
        assert.equal(control.length, 0, 'There is no working icon container for lane 1');
        control = $("#radio_rpt_key\\3A 18000\\3A 2_Accepted\\20 preliminary");
        assert.equal(control.attr('value'), 'Accepted preliminary', 'Correct value for Accepted preliminary control');
        assert.equal(control.attr('checked'), 'checked', 'Accepted is checked as per ajax qcoutcomes call');
        control = $("#radio_rpt_key\\3A 18000\\3A 2_Rejected\\20 preliminary");
        assert.equal(control.attr('value'), 'Rejected preliminary', 'Correct value for Rejected preliminary control');
        assert.notEqual(control.attr('checked'), 'checked', 'Rejected is not checked as per ajax qcoutcomes call');
        control = $("#radio_rpt_key\\3A 18000\\3A 2_Undecided");
        assert.equal(control.attr('value'), 'Undecided', 'Correct value for Undecided control');
        assert.notEqual(control.attr('checked'), 'checked', 'Undecided is not checked as per ajax qcoutcomes call');
        control = $("#rpt_key\\3a 18000\\3a 2 > td.lane.nbsp.td_mqc > span > span.lane_mqc_working");
        assert.equal(control.length, 1, 'Has a working icon container');
        assert.equal(control.children().length, 0, 'Working icon container is empty');

        assert.notOk($("#rpt_key\\3a 18000\\3a 1 > td.lane.nbsp.td_mqc > span > span.lane_mqc_button.lane_mqc_save").is(":visible"),
                     'Lane 1 with save button visible');
        assert.ok($("#rpt_key\\3a 18000\\3a 2 > td.lane.nbsp.td_mqc > span > span.lane_mqc_button.lane_mqc_save").is(":visible"),
                     'Lane 2 with save button visible');
      } catch (err) {
        console.log(err);
      } finally {
        $.ajax = initialAjax;
        $('title').text(initialTitle);
      }
    });

    QUnit.test("Display library manual qc mixed initial outcomes", function ( assert ) {
      assert.expect(41);
      //Set title
      document.title = 'NPG SeqQC v0: Results (all) for runs 18000 lanes 2 (run 18000 status: qc in progress, taken by aa11)';
      //Set fixtures
      var page_fixture = fixtures.fixtures_lib_mixed;
      $('#qunit-fixture').html(page_fixture);
      //Set return ajax call
      $.ajax = function (options) {
        var data = {
          "lib":{
            "18000:2:1":{"tag_index":"1","mqc_outcome":qc_utils.OUTCOMES.ACCEPTED_PRELIMINARY,"position":"2","id_run":"18000"},
            "18000:2:3":{"tag_index":"3","mqc_outcome":qc_utils.OUTCOMES.UNDECIDED,"position":"2","id_run":"18000"},
            "18000:2:2":{"tag_index":"2","mqc_outcome":qc_utils.OUTCOMES.REJECTED_PRELIMINARY,"position":"2","id_run":"18000"}
          },
          "seq":{},
          "uqc":{} 
        };
        options.success = function (callback) {
          callback(data, 'success', {});
          return options;
        };
        options.error = function () { return options; };
        return options;
      };

      try {
        runAsIfMain();
        var allNotChecked = [
          "#radio_rpt_key\\3a 18000\\3a 2\\3a 1_Undecided",
          "#radio_rpt_key\\3a 18000\\3a 2\\3a 1_Rejected\\20 preliminary",
          "#radio_rpt_key\\3a 18000\\3a 2\\3a 2_Accepted\\20 preliminary",
          "#radio_rpt_key\\3a 18000\\3a 2\\3a 2_Undecided",
          "#radio_rpt_key\\3a 18000\\3a 2\\3a 3_Accepted\\20 preliminary",
          "#radio_rpt_key\\3a 18000\\3a 2\\3a 3_Rejected\\20 preliminary",
          "#radio_rpt_key\\3a 18000\\3a 2\\3a 4_Accepted\\20 preliminary",
          "#radio_rpt_key\\3a 18000\\3a 2\\3a 4_Undecided",
          "#radio_rpt_key\\3a 18000\\3a 2\\3a 4_Rejected\\20 preliminary",
        ];
        for ( var i = 0; i < allNotChecked.length; i++ ) {
          var notCheckedSelector = allNotChecked[i];
          var notCheckedControl = $(notCheckedSelector);
          assert.notEqual(notCheckedControl.attr('checked'),
                          'checked',
                          'Control is not checked as per ajax qcoutcomes call');
        }

        var allChecked = [
          "#radio_rpt_key\\3a 18000\\3a 2\\3a 1_Accepted\\20 preliminary",
          "#radio_rpt_key\\3a 18000\\3a 2\\3a 2_Rejected\\20 preliminary",
          "#radio_rpt_key\\3a 18000\\3a 2\\3a 3_Undecided",
        ];
        for ( i = 0; i < allChecked.length; i++ ) {
          var checkedSelector = allChecked[i];
          var checkedControl = $(checkedSelector);
          assert.equal(checkedControl.attr('checked'),
                       'checked',
                       'Control is checked as per ajax qcoutcomes call');
        }

        var control = $("#rpt_key\\3a 18000\\3a 2 > td.lane.nbsp > span.library_mqc_overall_controls");
        assert.ok(control.is(':visible'), 'Placeholder for overall controls is visible');
        assert.equal($("#results_summary .library_mqc_overall_controls").length,
                     1, 'One overall control in page');
        assert.equal(control.attr('style'),
                     'padding-right: 5px; padding-left: 7px;',
                     'Overall controls have correct style.');
        var individualOverallButtons = [
          'lane_mqc_accept_all',
          'lane_mqc_reject_all',
          'lane_mqc_undecided_all'
        ];
        for ( i = 0; i < individualOverallButtons.length; i++ ) {
          var thisButton = control.find('.' + individualOverallButtons[i]);
          assert.ok(thisButton.is(':visible'),
             'Overall button is visible ' + individualOverallButtons[i]);
          assert.equal(thisButton.attr('style'),
                       'padding-left: 5px; background-color: rgb(244, 244, 244);',
                       'Button is not selected');
        }

        var plexesWithControls = [ 1, 2, 3, 4 ];
        for ( i = 0; i < plexesWithControls.length; i++ ) {
          var plex = plexesWithControls[i];
          var workingContainerSelector = "#rpt_key\\3a 18000\\3a 2\\3a " +
                                         plex +
                                         " > td.lane.nbsp.td_library_mqc > span > span";
          var workingContainerControl = $(workingContainerSelector);
          assert.equal(workingContainerControl.length,
                       1,
                       'Has a working icon container for plex ' + plex);
          assert.equal(workingContainerControl.children().length,
                       0,
                       'Working icon container is empty for plex ' + plex);

          var placeholder = $("#rpt_key\\3a 18000\\3a 2\\3a " +
                              plex +
                              " > td.lane.nbsp.td_library_mqc > span" );
          assert.equal(placeholder.attr('style'),
                       'padding-right: 5px; padding-left: 10px;',
                       "Correct style for plex " + plex + " control's span");
          var td = $("#rpt_key\\3a 18000\\3a 2\\3a " + plex + " > td.tag_info");
          assert.ok( !( td.hasClass("qc_outcome_accepted_preliminary") ||
                        td.hasClass("qc_outcome_rejected_preliminary") ||
                        td.hasClass("qc_outcome_undecided") ),
                     'tag index cell has no preliminary class');
        }
        var plexesWithoutControls = [ 0, 888 ];
        for ( i = 0; i < plexesWithoutControls.length; i++ ) {
          plex = plexesWithoutControls[i];
          td = $("#rpt_key\\3a 18000\\3a 2\\3a " + plex + " > td.lane.nbsp");
          assert.equal(td.children().length, 0, 'No controls in td for plex ' + plex);
          assert.ok( !(td.hasClass("qc_outcome_accepted_preliminary") ||
                       td.hasClass("qc_outcome_rejected_preliminary") ||
                       td.hasClass("qc_outcome_undecided") ),
                     'tag index cell has no preliminary class');
        }
      } catch (err) {
        console.log(err);
      } finally {
        $.ajax = initialAjax;
        $('title').text(initialTitle);
      }
    });

    QUnit.test("Lib not in mqc", function ( assert ) {
      var cases = [
        { title: 'NPG SeqQC v0: Results (all) for runs 18000 lanes 2 (run 18000 status: qc in progress, taken by aa11)',
          logged: ' Not logged in'
        },
        { title: 'NPG SeqQC v0: Results (all) for runs 18000 lanes 2 (run 18000 status: qc in progress, taken by aa11)',
          logged: 'Logged in as bb22 (mqc)'
        },
        { title: 'NPG SeqQC v0: Results (all) for runs 18000 lanes 2 (run 18000 status: qc in progress, taken by aa11)',
          logged: 'Logged in as bb22'
        },
        { title: 'NPG SeqQC v0: Results (all) for runs 18000 lanes 2 (run 18000 status: qc in progress, taken by aa11)',
          logged: 'Logged in as aa11'
        },
        { title: 'NPG SeqQC v0: Results (all) for runs 18000 lanes 2 (run 18000 status: qc review pending)',
          logged: 'Logged in as aa11 (mqc)'
        }
      ];
      assert.expect(cases.length * 15);

      var page_fixture = fixtures.fixtures_lib_mixed;
      //Set return ajax call
      $.ajax = function (options) {
        var data = {
          "lib":{
            "18000:2:1":{"tag_index":"1","mqc_outcome":qc_utils.OUTCOMES.ACCEPTED_PRELIMINARY,"position":"2","id_run":"18000"},
            "18000:2:2":{"tag_index":"2","mqc_outcome":qc_utils.OUTCOMES.REJECTED_PRELIMINARY,"position":"2","id_run":"18000"}
          },
          "seq":{
            "18000:2":{"mqc_outcome":qc_utils.OUTCOMES.ACCEPTED_PRELIMINARY,"position":"2","id_run":"18000"}
          },
          "uqc":{} 
        };
        options.success = function (callback) {
          callback(data, 'success', {});
          return options;
        };
        options.error = function () { return options; };
        return options;
      };

      try {
        for ( var j = 0; j < cases.length; j++ ) {
          var thisCase = cases[j];
          document.title = thisCase.title;

          $('#qunit-fixture').html(page_fixture);
          $("#header > h1 > span.lfloat.env_dev").text(thisCase.title);
          $("#header > h1 > span.rfloat").text(thisCase.logged);

          runAsIfMain();
          assert.ok($("#rpt_key\\3a 18000\\3a 2\\3a 1 > td.tag_info").hasClass('qc_outcome_accepted_preliminary'));
          assert.ok($("#rpt_key\\3a 18000\\3a 2\\3a 2 > td.tag_info").hasClass('qc_outcome_rejected_preliminary'));

          var emptyContainers = [
            "#rpt_key\\3a 18000\\3a 2 > td.lane.nbsp > span.lane_mqc_control",
            "#rpt_key\\3a 18000\\3a 2 > td.lane.nbsp > span.library_mqc_overall_controls",
            "#rpt_key\\3a 18000\\3a 2\\3a 1 > td.lane.nbsp > span",
            "#rpt_key\\3a 18000\\3a 2\\3a 2 > td.lane.nbsp > span",
          ];
          for ( var i = 0; i < emptyContainers.length; i++ ) {
            var emptyContainer = emptyContainers[i];
            assert.equal($(emptyContainer).children().length,
                         0,
                         'Container is empty ' + emptyContainer);
          }

          var allRows = [
            "#rpt_key\\3a 18000\\3a 2",
            "#rpt_key\\3a 18000\\3a 2\\3a 1",
            "#rpt_key\\3a 18000\\3a 2\\3a 2",
            "#rpt_key\\3a 18000\\3a 2\\3a 888",
            "#rpt_key\\3a 18000\\3a 2\\3a 0"
          ];
          for ( i = 0; i < allRows.length; i++ ) {
            var row = allRows[i];
            var laneTd = $(row + " > td.lane.nbsp");
            assert.ok(laneTd.hasClass("qc_outcome_accepted_preliminary"),
                      'lane cell has preliminary class');
          }


          var plexesWithoutControls = [ 0, 888 ];
          for ( i = 0; i < plexesWithoutControls.length; i++ ) {
            var plex = plexesWithoutControls[i];
            var td = $("#rpt_key\\3a 18000\\3a 2\\3a " + plex + " > td.lane.nbsp");
            assert.equal(td.children().length, 0, 'No controls in lane td for plex ' + plex);

            td = $("#rpt_key\\3a 18000\\3a 2\\3a " + plex + " > td.tag_info");
            assert.notOk( td.hasClass("qc_outcome_accepted_preliminary") ||
                         td.hasClass("qc_outcome_rejected_preliminary") ||
                         td.hasClass("qc_outcome_undecided") ,
                       'tag index cell has no preliminary class');
          }
        }
      } catch (err) {
        console.log(err);
      } finally {
        $.ajax = initialAjax;
        $('title').text(initialTitle);
      }
    });

    QUnit.test("Seq not in mqc", function ( assert ) {
      var cases = [
        { title: 'NPG SeqQC v0: Results for run 18000 (run 18000 status: qc in progress, taken by aa11)',
          logged: ' Not logged in'
        },
        { title: 'NPG SeqQC v0: Results for run 18000 (run 18000 status: qc in progress, taken by aa11)',
          logged: 'Logged in as bb22 (mqc)'
        },
        { title: 'NPG SeqQC v0: Results for run 18000 (run 18000 status: qc in progress, taken by aa11)',
          logged: 'Logged in as bb22'
        },
        { title: 'NPG SeqQC v0: Results for run 18000 (run 18000 status: qc in progress, taken by aa11)',
          logged: 'Logged in as aa11'
        },
        { title: 'NPG SeqQC v0: Results for run 18000 (run 18000 status: qc review pending)',
          logged: 'Logged in as aa11 (mqc)'
        }
      ];
      assert.expect(cases.length * 4 * ( Object.keys(qc_utils.OUTCOMES).length - 1 ));

      var toClass = function ( outcome ) {
        return 'qc_outcome_' + outcome.toLowerCase().replace(' ', '_');
      };

      var page_fixture = fixtures.fixtures_seq_mixed;
      var testNotMQC = function (expectedClass) {
        try {
          for ( var j = 0; j < cases.length; j++ ) {
            var thisCase = cases[j];
            document.title = thisCase.title;

            $('#qunit-fixture').html(page_fixture);
            $("#header > h1 > span.lfloat.env_dev").text(thisCase.title);
            $("#header > h1 > span.rfloat").text(thisCase.logged);

            runAsIfMain();
            assert.ok($("#rpt_key\\3a 18000\\3a 1 > td.lane.nbsp").hasClass(expectedClass), 'With proper class in lane');
            assert.ok($("#rpt_key\\3a 18000\\3a 2 > td.lane.nbsp").hasClass(expectedClass), 'With proper class in lane');

            var emptyContainers = [
              "#rpt_key\\3a 18000\\3a 1 > td.lane.nbsp > span.lane_mqc_control",
              "#rpt_key\\3a 18000\\3a 2 > td.lane.nbsp > span.lane_mqc_control",
            ];
            for ( var i = 0; i < emptyContainers.length; i++ ) {
              var emptyContainer = emptyContainers[i];
              assert.equal($(emptyContainer).children().length,
                           0,
                           'Container is empty ' + emptyContainer);
            }
          }
        } catch (err) {
          console.log(err);
        } finally {
          $.ajax = initialAjax;
          $('title').text(initialTitle);
        }
      };

      for ( var outcomeName in qc_utils.OUTCOMES ) {
        var outcome = qc_utils.OUTCOMES[outcomeName];

        if ( outcome === qc_utils.OUTCOMES.UNDECIDED_FINAL ) { // No undecided final for lane
          continue;
        }

        //Set return ajax call
        $.ajax = function (options) {
          var data = {
            "lib":{},
            "seq":{
              "18000:1":{"mqc_outcome":outcome,"position":"1","id_run":"18000"},
              "18000:2":{"mqc_outcome":outcome,"position":"2","id_run":"18000"}
            },
            "uqc":{} 
          };
          options.success = function (callback) {
            callback(data, 'success', {});
            return options;
          };
          options.error = function () { return options; };
          return options;
        };
        testNotMQC(toClass(outcome));
      }
    });

    QUnit.test("In MQC but nothing to MQC", function ( assert ) {
      var thisCase = {
        title: 'NPG SeqQC v0: Results (all) for runs 18000 lanes 2 (run 18000 status: qc in progress, taken by aa11)',
        logged: 'Logged in as aa11'
      };

      assert.expect(13);
      var page_fixture = fixtures.fixtures_lib_nothing_to_qc;
      //Set return ajax call
      $.ajax = function (options) {
        var data = {
          "lib":{
            "18000:2:1":{"tag_index":"1","mqc_outcome":qc_utils.OUTCOMES.ACCEPTED_PRELIMINARY,"position":"2","id_run":"18000"},
            "18000:2:2":{"tag_index":"2","mqc_outcome":qc_utils.OUTCOMES.ACCEPTED_PRELIMINARY,"position":"2","id_run":"18000"}
          },
          "seq":{
            "18000:2":{"mqc_outcome":qc_utils.OUTCOMES.ACCEPTED_PRELIMINARY,"position":"2","id_run":"18000"}
          },
          "uqc":{} 
        };
        options.success = function (callback) {
          callback(data, 'success', {});
          return options;
        };
        options.error = function () { return options; };
        return options;
      };

      try {
        document.title = thisCase.title;

        $('#qunit-fixture').html(page_fixture);
        $("#header > h1 > span.lfloat.env_dev").text(thisCase.title);
        $("#header > h1 > span.rfloat").text(thisCase.logged);

        runAsIfMain();
        assert.ok($("#rpt_key\\3a 18000\\3a 2\\3a 1 > td.tag_info").hasClass('qc_outcome_accepted_preliminary'));
        assert.ok($("#rpt_key\\3a 18000\\3a 2\\3a 2 > td.tag_info").hasClass('qc_outcome_accepted_preliminary'));

        assert.equal($('#results_summary .lane_mqc_control').length, 0, 'No libs or lanes for qc');
        assert.equal($("#rpt_key\\3a 18000\\3a 2 > td.lane.nbsp > span.library_mqc_overall_controls").children().length,
                     0, 'Container is empty');

        var allRows = [
        "#rpt_key\\3a 18000\\3a 2",
        "#rpt_key\\3a 18000\\3a 2\\3a 1",
        "#rpt_key\\3a 18000\\3a 2\\3a 2",
        "#rpt_key\\3a 18000\\3a 2\\3a 888",
        "#rpt_key\\3a 18000\\3a 2\\3a 0"
        ];
        for ( var i = 0; i < allRows.length; i++ ) {
        var row = allRows[i];
        var laneTd = $(row + " > td.lane.nbsp");
        assert.ok(laneTd.hasClass("qc_outcome_accepted_preliminary"),
                  'lane cell has preliminary class');
        }

        var plexesWithoutControls = [ 0, 888 ];
        for ( i = 0; i < plexesWithoutControls.length; i++ ) {
        var plex = plexesWithoutControls[i];
        var td = $("#rpt_key\\3a 18000\\3a 2\\3a " + plex + " > td.lane.nbsp");
        assert.equal(td.children().length, 0, 'No controls in lane td for plex ' + plex);

        td = $("#rpt_key\\3a 18000\\3a 2\\3a " + plex + " > td.tag_info");
        assert.notOk( td.hasClass("qc_outcome_accepted_preliminary") ||
                        td.hasClass("qc_outcome_rejected_preliminary") ||
                        td.hasClass("qc_outcome_undecided"),
                      'tag index cell has no preliminary class');
        }
      } catch (err) {
        console.log(err);
      } finally {
        $.ajax = initialAjax;
        $('title').text(initialTitle);
      }
    });

    QUnit.test("DOM linking", function( assert ) {
      var lane = $("#mqc_lane1");
      var control = new NPG.QC.LaneMQCControl(new TestConfiguration());
      assert.notEqual(control, undefined, "Control is an instance.");
      control.linkControl(lane);
      assert.notEqual(control.lane_control, undefined, "lane_control in Control is linked.");
      assert.equal(control.lane_control, lane, "Control and lane are correctly linked.");
      assert.equal(control.lane_control.outcome, undefined, "Outcome of lane is not defined.");
    });

    QUnit.test('Object initialisation', function( assert ) {
      var obj = null;
      assert.ok(obj == null, "Variable is initially null.");
      obj = new NPG.QC.LaneMQCControl();
      assert.ok(obj !== undefined, "Variable is now an instance.");
      obj = new NPG.QC.LaneMQCControl(new TestConfiguration());
      assert.ok(obj !== undefined, "Variable is now a new instance called with parameter for constructor.");
      assert.ok(obj.lane_control == null, "New object has null lane_control.");
      assert.ok(obj.abstractConfiguration !== undefined, 'Object has a configuration');
      assert.ok(obj.outcome == null, "New object has null outcome.");

      obj = null;
      assert.ok(obj == null, "Variable back to null.");
      obj = new NPG.QC.LibraryMQCControl();
      assert.ok(obj !== undefined, "Variable is now an instance.");
      obj = new NPG.QC.LibraryMQCControl(new TestConfiguration());
      assert.ok(obj !== undefined, "Variable is now a new instance called with parameter for constructor.");
      assert.ok(obj.lane_control == null, "New object has null lane_control.");
      assert.ok(obj.abstractConfiguration !== undefined, 'Object has a configuration');
      assert.ok(obj.outcome == null, "New object has null outcome.");
    });

    QUnit.test('Object instantiation for UI classes.', function( assert ) {
      var obj = null;

      obj = new NPG.QC.UI.MQCOutcomeRadio();
      assert.ok(obj !== undefined, 'Variable is now an instance of MQCOutcomeRadio');
      obj = null;
      assert.ok(obj == null);

      obj = new NPG.QC.UI.MQCLibraryOverallControls(new TestConfiguration());
      assert.ok(obj !== undefined, 'Variable is now an instance of MQCLibraryOverallControls');
      obj = null;
      assert.ok(obj == null);
    });
    
    // start QUnit because it was told to wait.
    QUnit.start();
  }
);

