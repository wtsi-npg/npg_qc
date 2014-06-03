// Author: ajb

function get_summary_heatmap(url, id_run, datatype) {
  Element.show('spinner');
  new Ajax.Updater('heatmaps',url,
 {method:'get',
  parameters:{id_run:id_run, datatype:datatype},
  onComplete:function(){
   Element.hide('spinner');
 }});
}

function open_tile_viewer(url) {
  window.open(url,'Window1','menubar=no,width=1024,height=900,toolbar=no,scrollbars=yes');
}

function up_heatmap_movez(id_run, url, form){ 

  Element.show('spinner');  
  var cycle = form.cycle.value;
  var cycle_ref = id_run + '_' + cycle;
  var el = 'heatmap_view';
  new Ajax.Updater(el, url +'/move_z/;list_heatmap_with_hover_ajax',
   {method:'get',
    parameters:{cycle_ref:cycle_ref, url: url + '/move_z/;list_heatmap_png?id_run=' + id_run + '&cycle='+ cycle +'&thumb=false'},
    onComplete:function(){
     Element.hide('spinner');
   }});
}

function run_tile_page (url) {
  window.open(url, 'Run Tile');
}
