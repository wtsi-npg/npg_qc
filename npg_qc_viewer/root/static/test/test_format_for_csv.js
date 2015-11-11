"use strict";
require.config({
  baseUrl: '../',
  paths: {
    jquery: 'bower_components/jquery/jquery',
  },
});

require(['scripts/format_for_csv',],
  function(format_for_csv) {
    // run the tests.
    QUnit.test('Preparing table for download as csv', function (assert) {
      var tableHtml = $('#results_summary')[0].outerHTML;

      var indexLibrary = tableHtml.indexOf('Library');
      assert.equal(indexLibrary, 105, 'Text contains Library (content of first th)');

      assert.equal(tableHtml.indexOf('<br>'), 112, 'Text has <br> in expected position');
      assert.equal(tableHtml.indexOf('|'), -1, 'Text does not have pipes');
      assert.equal(tableHtml.indexOf('&nbsp;'), 457, 'Text has nbsp in expected position');
      var withoutBreaksNbsp = format_for_csv._removeBreaks(tableHtml);

      assert.equal(withoutBreaksNbsp.indexOf('<br>'), -1, 'No more <br> in table');
      assert.equal(withoutBreaksNbsp.indexOf('<br >'), -1, 'No more <br > in table');
      assert.equal(withoutBreaksNbsp.indexOf('<br />'), -1, 'No more <br /> in table');
      assert.equal(withoutBreaksNbsp.indexOf('|'), 112, 'Replaced <br> with pipe in expected position');
      assert.equal(withoutBreaksNbsp.indexOf('&nbsp;'), -1, 'No more nbsp in table');

      var withFullHeaders = $(withoutBreaksNbsp);
      assert.equal(tableHtml.indexOf('adapters,'), 291, 'Second header is there - testing contents');
      assert.equal(tableHtml.indexOf('rowspan'), 93, 'Rowspans in header - testing contents');
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
      assert.equal(newTableHtml.indexOf('|'), 100, 'Replaced <br> with pipe in expected position after format');
      assert.equal(newTableHtml.indexOf('adapters,'), -1, 'Second header row is gone after format');
      assert.equal(newTableHtml.indexOf('rowspan'), -1, 'No rowspans in header after format');
    });
    QUnit.start();
  }
);

