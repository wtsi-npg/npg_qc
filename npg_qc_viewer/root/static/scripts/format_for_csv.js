/*
 * Functionality to format the SeqQC summary table for export to CSV using
 * hhurz/tableExport.jquery.plugin
 *
 * Example:
 *
 * var table_html = $('#results_summary')[0].outerHTML;
 * var formated_table = format_for_csv.format(table_html);
 *
 * Returns : a new element not linked to DOM. The element has the format
 * required for exporting to CSV using the library.
 *
 */
define(['jquery'], function (jQuery) {

  var regexp = new RegExp('<[\s]*br[\s]*[/]?[\s]*>', 'gim');

  var removeBreaks = function (htmlText) {
    return htmlText.replace(regexp, '|');
  };

  var fixHeaders = function (obj) {
    obj.find('thead').find('tr:gt(0)').remove(); //2nd+ row in headers
    obj.find('th').removeAttr('rowspan'); // Not needed rowspans in headers
  };

  var markForExport = function(obj) {
    obj.data('tableexport-display', 'always');
  };

  var format = function (table_html) {
    var without_br = removeBreaks(table_html);
    var tempTable = jQuery(without_br);
    fixHeaders(tempTable);
    markForExport(tempTable);
    return tempTable;
  };

  return {
    _removeBreaks : removeBreaks,
    _fixHeaders : fixHeaders,
    _markForExport : markForExport,
    format : format
  };
});

