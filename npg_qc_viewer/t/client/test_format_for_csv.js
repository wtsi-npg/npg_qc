/* globals $, QUnit, requirejs */
"use strict";
requirejs.config({
  baseUrl: '../../root/static',
  paths: {
    'qunit': 'bower_components/qunit/qunit/qunit',
    jquery:  'bower_components/jquery/dist/jquery'
  }
});

requirejs(['scripts/format_for_csv',],
  function(format_for_csv) {
    QUnit.config.autostart = false;
    QUnit.module('Fixing table contents');
    QUnit.test('Preparing table for download as csv', function (assert) {
      var tableHtml = $('#results_summary')[0].outerHTML;

      var indexLibrary = tableHtml.indexOf('Library');
      assert.equal(indexLibrary, 115, 'Text contains Library (content of first th)');

      assert.equal(tableHtml.indexOf('<br>'), 122, 'Text has <br> in expected position');
      assert.equal(tableHtml.indexOf('|'), -1, 'Text does not have pipes');
      assert.equal(tableHtml.indexOf('&nbsp;'), 503, 'Text has nbsp in expected position');
      var withoutBreaksNbsp = format_for_csv._removeBreaks(tableHtml);

      assert.equal(withoutBreaksNbsp.indexOf('<br>'), -1, 'No more <br> in table');
      assert.equal(withoutBreaksNbsp.indexOf('<br >'), -1, 'No more <br > in table');
      assert.equal(withoutBreaksNbsp.indexOf('<br />'), -1, 'No more <br /> in table');
      assert.equal(withoutBreaksNbsp.indexOf('|'), 122, 'Replaced <br> with pipe in expected position');
      assert.equal(withoutBreaksNbsp.indexOf('&nbsp;'), -1, 'No more nbsp in table');

      var withFullHeaders = $(withoutBreaksNbsp);
      assert.equal(tableHtml.indexOf('adapters,'), 317, 'Second header is there - testing contents');
      assert.equal(tableHtml.indexOf('rowspan'), 103, 'Rowspans in header - testing contents');
      format_for_csv._fixHeaders(withFullHeaders);
      tableHtml = withFullHeaders[0].outerHTML;
      assert.equal(tableHtml.indexOf('<br>'), -1, 'Still no <br>');
      assert.equal(tableHtml.indexOf('adapters,'), -1, 'Second header row is gone - testing contents');
      assert.equal(tableHtml.indexOf('rowspan'), -1, 'No rowspans in header - testing contents');

      format_for_csv._markForExport(withFullHeaders);
      assert.equal(withFullHeaders.data('tableexport-display'), 'always', 'Table marked for export');

      var newTable = format_for_csv.format(tableHtml);
      assert.equal(newTable.data('tableexport-display'), 'always', 'Table marked for export after format');

      var newTableHtml = newTable[0].outerHTML;
      assert.equal(newTableHtml.indexOf('<br>'), -1, 'No more <br> after format');
      assert.equal(newTableHtml.indexOf('<br >'), -1, 'No more <br > after format');
      assert.equal(newTableHtml.indexOf('<br />'), -1, 'No more <br /> after format');
      assert.equal(newTableHtml.indexOf('|'), 110, 'Replaced <br> with pipe in expected position after format');
      assert.equal(newTableHtml.indexOf('adapters,'), -1, 'Second header row is gone after format');
      assert.equal(newTableHtml.indexOf('rowspan'), -1, 'No rowspans in header after format');
    });

    QUnit.module('Adding extra columns with data- markup');
    var small_table = [
      '<table id="small_table">',
      '  <tr id="tr1">',
      '    <th id="th1">header 1</th><th id="th2">header 2</th>',
      '  </tr>',
      '  <tr id="tr2">',
      '    <td id="td1">data 1</td><td id="td2">data 2</td>',
      '  </tr>',
      '</table>',
    ].join("\n");
    QUnit.test('Throws with wrong params', function (assert) {
      $('#qunit-fixture').append(small_table);
      assert.throws(
        function() {
          format_for_csv.addDataColumns();
        },
        /method requires 'table' parameter/,
        "raises exception with no table param"
      );
      assert.throws(
        function() {
          format_for_csv.addDataColumns($('#small'));
        },
        /method requires table parameter to be a JQuery wrapped table/,
        "raises exception with non table param"
      );
      assert.throws(
        function() {
          format_for_csv.addDataColumns($('#small_table'));
        },
        /method requires 'data_prefix' parameter to be of type string/,
        "raises exception with no data_prefix param"
      );
      assert.throws(
        function() {
          format_for_csv.addDataColumns($('#small_table'), 'some_prefix');
        },
        /method requires 'data_field_name_list' parameter to be of type Array/,
        "raises exception with no data_field_name_list param"
      );
      assert.throws(
        function() {
          format_for_csv.addDataColumns($('#small_table'), 'some_prefix', 'field_name');
        },
        /method requires 'data_field_name_list' parameter to be of type Array/,
        "raises exception with wront type for data_prefix param"
      );
    });
    QUnit.test('Add columns - table is not changed when there are no cells marked', function (assert) {
      $('#qunit-fixture').append(small_table);
      assert.equal($('#small_table tr').length, 2);
      $('#small_table tr').each(function(i, row){
        assert.equal($(row).find('td, th').length, 2, 'Row has two cells');
      });
      ['tr', 'th' , 'td'].forEach(function(name) {
        for(var j = 0; j < 2; ++j) {
          var element_id = '#' + name + (j + 1);
          assert.equal($(element_id).length, 1, 'found element ' + element_id);
        }
      });

      var some_prefix = 'some_prefix_';
      var field_names = ['field1'];
      format_for_csv.addDataColumns($('#small_table'), some_prefix, field_names);

      assert.equal($('#small_table tr').length, 2);
      $('#small_table tr').each(function(i, row){
        assert.equal($(row).find('td, th').length, 2, 'Row has two cells');
      });
    });

    [
      [], // Should result in no new columns
      ['field1'],
      ['field1', 'field2', 'field3']
    ].forEach(function(field_names) {
      var test_desc = 'Add columns - table gets extra column (' +
                      field_names.length +
                      ') when cells marked';
      QUnit.test(test_desc, function (assert) {
        $('#qunit-fixture').append(small_table);
        assert.equal($('#small_table tr').length, 2, 'Two rows in table');
        $('#small_table tr').each(function(i, row) {
          assert.equal($(row).find('td, th').length, 2, 'Row has two cells');
        });
        ['tr', 'th' , 'td'].forEach(function(name) {
          for(var j = 0; j < 2; ++j) {
            var element_id = '#' + name + (j + 1);
            assert.equal($(element_id).length, 1, 'found element ' + element_id);
          }
          $(name).addClass('old_element');
        });

        var some_prefix = 'some_prefix_';

        ['th1', 'td1'].forEach(function(name) {
          $('#' + name).each(function(i, element) {
            field_names.forEach(function(field_name) {
              $(element).data(some_prefix + field_name, 'Content for ' + field_name);
            });
          });
        });

        format_for_csv.addDataColumns($('#small_table'), some_prefix, field_names);

        assert.equal($('#small_table tr').length, 2, 'two rows present in table');
        $('#small_table tr').each(function(i, row){
          var total_columns_expected = 2 + field_names.length;
          var $row = $(row);
          assert.equal(
            $row.find('td, th').length,
            total_columns_expected,
            'Row has ' + total_columns_expected + ' cells'
          );
          $row.find('td, th').each(function(j, cell) {
            var $cell = $(cell);
            if($cell.hasClass('old_element')) {
              assert.ok(/^(header)|(data) [\d]$/.test($cell.text()), 'old cell keeps old content');
            } else {
              assert.ok(/^Content for field[\d]+$/.test($cell.text()), 'new cell has new content');
            }
          });
          var all_content = $row.text();

          // Find where each content bit appears
          var positions = field_names.map(function(field_name) {
            return all_content.search(new RegExp('Content for ' + field_name));
          });

          // Make copy and sort in place
          var sorted_positions = positions.slice().sort();

          assert.ok(positions.every(function(element, index) {
            return element === sorted_positions[index];
          }), 'Columns in expected order');
        });
      });
    });



    QUnit.start();
  }
);
