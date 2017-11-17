/* globals define: true, $: true */
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
"use strict";
define(['jquery'], function (jQuery) {

  var regexp = new RegExp('<[\s]*br[\s]*[/]?[\s]*>', 'gim');
  var regexp_n = new RegExp('&nbsp;', 'gim');

  var removeBreaks = function (htmlText) {
    var text = htmlText.replace(regexp, '|');
    text = text.replace(regexp_n, ' ');
    return text;
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

  /**
   * Modifies a table passed as parameter in place. Will test for td elements
   * with data entries matching the prefix + data field name pattern. Will add a
   * td after the original td for each of the matching data fields. The td
   * sibblings will be inserted in the order they appear in the field name list.
   * @param  {JQuery} table               table element as wrapped JQuery object
   * @param  {string} data_prefix         prefix for data names to be considered
   *                                      as candidates to transform to new cols
   * @param  {Array} data_field_name_list array of strings with column names to
   *                                      pick. Each string will be prepended
   *                                      with the data_prefix to figure out keys
   *                                      to use from the object data from each
   *                                      td element.
   * @example
   *
   * var extra_data_fields = ['field1', 'other_field'];
   * var extra_column_prefix = 'extra_column_';
   * var $table = $('#' + table_id);
   * addColumns($table, extra_column_prefix, extra_data_fields);
   */
  var addDataColumns = function(table, data_prefix, data_field_name_list) {
    if(typeof table !== 'object') {
      throw "method requires 'table' parameter";
    }
    if(!table.is('table')) {
      throw 'method requires table parameter to be a JQuery wrapped table';
    }
    if(typeof data_prefix !== 'string') {
      throw "method requires 'data_prefix' parameter to be of type string";
    }
    if(typeof data_field_name_list !== 'object' || data_field_name_list.constructor !== Array) {
      throw "method requires 'data_field_name_list' parameter to be of type Array";
    }

    // Use slice() to get copy because reverse happens in place
    var field_name_list_copy = data_field_name_list.slice().reverse();
    var data_field_names_w_prefix = field_name_list_copy.map(function(name) {
      return data_prefix + name;
    });

    table.find('tr').each(function(i, row_element) {
      $(row_element).find('th,td').each(function(j, cell_element) {
        var $cell_element = $(cell_element);
        var $cell_element_data = $cell_element.data();
        data_field_names_w_prefix.forEach(function(data_field_name) {
          if (typeof $cell_element_data[data_field_name] !== 'undefined') {
            var new_data = $cell_element_data[data_field_name];
            if ($cell_element.is('td')) {
              $cell_element.after('<td>' + new_data + '</td>');
            } else {
              $cell_element.after('<th>' + new_data + '</th>');
            }
          }
        });
      });
    });
  };

  return {
    _removeBreaks:  removeBreaks,
    _fixHeaders:    fixHeaders,
    _markForExport: markForExport,
    addDataColumns: addDataColumns,
    format:         format
  };
});

