"use strict";
define([], function () {
  var fixtures_dont_display = [
    '<div id="header">',
    '  <h1>',
    '    <a name="page_top"></a>&nbsp;',
    '    <span class="lfloat env_dev">NPG SeqQC v0: Results for run 18904 (run 18904 status: qc in progress, taken by jmtc)</span>',
    '    <span class="rfloat">Logged in as jmtc (mqc)</span>',
    '  </h1>',
    '</div>',
    '<table id="results_summary" summary="QC results summary">',
    ' <thead>',
    ' <tr>',
    '  <th rowspan="2">Library<br />------<br />Sample<br />Name</th>',
    '  <th rowspan="2">Run Id<br />------<br />Num.<br />Cycles</th><th rowspan="2">Lane<br />No</th><th>tag<br />metrics<br/></th>',
    ' </tr>',
    ' <tr><th class="check_labels">decode rate, %<br />CV %</th></tr>',
    ' </thead>',
    ' </tr><tr id="rpt_key:18904:2">',
    '  <td class="lib nbsp">',
    '  </td>',
    '  <td class="id_run">',
    '   <div class="rel_pos_container">',
    '   <br />158</div>',
    '  </td>',
    '  <td class="lane nbsp">',
    '   <a href="#18904:2">2   </a><span class="lane_mqc_control"></span></td> <td class="check_summary passed"><a href="#tmc_18904:2">99.18</a><br />',
    '   <span class="dark_blue"><a href="#tmc_18904:2">38.88</a></span></td>',
    ' </tr>',
    '</table>'
  ].join("\n");

  return {
    fixtures_dont_display: fixtures_dont_display
  };
});

