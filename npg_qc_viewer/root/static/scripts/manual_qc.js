/*
* Author:        Marina Gourtovaia
*
* Copyright (C) 2014 Genome Research Ltd.
*
* This file is part of NPG software.
*
* NPG is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

/************************************************************************************
*
* Interface for manual QC.
* Dependencies: jQuery library
*
************************************************************************************/

/*
 * Controller for individual lanes GUI.
 */
var LaneMQCControl = function (index) {
  this.lane_control = null;  // Container linked to this controller
  this.outcome      = null;  // Current outcome (Is updated when linked to an object in the view)
  this.index        = index; // Index of control in the page.
  
  this.CONFIG_UPDATE_SERVICE      = "/mqc/update_outcome";
  this.CONFIG_ACCEPTED_PRELIMINAR = 'Accepted preliminary';
  this.CONFIG_REJECTED_PRELIMINAR = 'Rejected preliminary';
  this.CONFIG_ACCEPTED_FINAL      = 'Accepted final';
  this.CONFIG_REJECTED_FINAL      = 'Rejected final';
  this.CONFIG_INITIAL             = 'initial';
  
  this.updateOutcome = function(outcome) {
    var id_run = this.lane_control.data('id_run'); 
    var position = this.lane_control.data('position');
    var control = this;
    if(outcome != control.outcome) {
      //Show progress icon
      control.lane_control.find('.lane_mqc_working').html("<img src='/static/images/waiting.gif' title='Processing request.'>");
      //AJAX call.
      $.post(control.CONFIG_UPDATE_SERVICE, { id_run: id_run, position : position, new_oc : outcome}, function(data){
        var response = data;
        window.console && console.log(response.message);
        control.lane_control.find('.lane_mqc_working').empty();
      }, "json")
      .done(function() {
        switch (outcome) {
          case control.CONFIG_ACCEPTED_PRELIMINAR : control.setAcceptedPre(); break; 
          case control.CONFIG_REJECTED_PRELIMINAR : control.setRejectedPre(); break;
          case control.CONFIG_ACCEPTED_FINAL : control.setAcceptedFinal(); break;
          case control.CONFIG_REJECTED_FINAL : control.setRejectedFinal(); break;
        }
        //Clear progress icon
        control.lane_control.find('.lane_mqc_working').empty();
      })
      .fail(function(data) {
        window.console && console.log(data.responseJSON.message);
        jQuery("#ajax_status").append("<li class='failed_mqc'>" + data.responseJSON.message + "</li>");
        //Clear progress icon
        control.lane_control.find('.lane_mqc_working').empty();
      });  
    } else {
      window.console && console.log("Noting to do.");
    }
  };
  
  /* 
   * Builds the gui controls necessary for the mqc operation and passes them to the view. 
   */ 
  this.generateActiveControls = function() {
    var lane_control = this.lane_control;
    this.lane_control.html("<img class='lane_mqc_control_accept' src='/static/images/tick.png' title='Accept'> <img class='lane_mqc_control_reject' src='/static/images/cross.png' title='Reject'> <div class='lane_mqc_working'></div>");    
    
    this.lane_control.find('.lane_mqc_control_accept').bind({click: function() {
      lane_control.extra_handler.updateOutcome(lane_control.extra_handler.CONFIG_ACCEPTED_FINAL);
    }});
    
    this.lane_control.find('.lane_mqc_control_reject').bind({click: function() {
      lane_control.extra_handler.updateOutcome(lane_control.extra_handler.CONFIG_REJECTED_FINAL);
    }});
    
    this.lane_control.find('.lane_mqc_control_save').bind({click: function() {
      lane_control.extra_handler.saveAsFinalOutcome();
    }});
    
  };
  
  /* 
   * Checks the current outcome associated with this controller. If it is not final it will make it final
   * will update the value in the model with an async call and update the view. 
   */
  this.saveAsFinalOutcome = function() {
    var control = this;
    
    if(this.outcome === this.CONFIG_ACCEPTED_PRELIMINAR) {
      this.updateOutcome(this.CONFIG_ACCEPTED_FINAL);
    }
    if(this.outcome === this.CONFIG_REJECTED_PRELIMINAR) {
      this.updateOutcome(this.CONFIG_REJECTED_FINAL);
    } 
  };
  
  /* 
   * Methods to deal with background colours. 
   */
  this.setAcceptedBG = function() {
    this.lane_control.parent().css("background-color", "#B5DAFF");
  }
  
  this.setRejectedBG = function () {
    this.lane_control.parent().css("background-color", "#FFDDDD");
  }
  
  this.setAcceptedPre = function() {
    this.outcome = this.CONFIG_ACCEPTED_PRELIMINAR;    
    this.setAcceptedBG();
  };
  
  this.setRejectedPre = function() {
    this.outcome = this.CONFIG_REJECTED_PRELIMINAR;
    this.setRejectedBG();
  };
  
  this.setAcceptedFinal = function() {
    this.outcome = this.CONFIG_ACCEPTED_FINAL;
    this.setAcceptedBG();
  };
  
  this.setRejectedFinal = function() {
    this.outcome = this.CONFIG_REJECTED_FINAL;
    this.setRejectedBG();
  };
  
  this.replaceForLink = function() {
    var id_run = this.lane_control.data('id_run'); 
    var position = this.lane_control.data('position');
    this.lane_control.empty();
  };
  
  /* 
   * Links the individual object with an mqc controller so it can allow mqc of a lane.
   */
  this.linkControl = function(lane_control) {
    lane_control.extra_handler = this;
    this.lane_control = lane_control;
    if ( typeof lane_control.data(this.CONFIG_INITIAL) == 'undefined') {
      //If it does not have initial outcome
      this.generateActiveControls();
    } else if (lane_control.data(this.CONFIG_INITIAL) === this.CONFIG_ACCEPTED_PRELIMINAR 
        || lane_control.data(this.CONFIG_INITIAL) === this.CONFIG_REJECTED_PRELIMINAR) {
      //If previous outcome is preliminar.
      this.generateActiveControls();
      switch (lane_control.data(this.CONFIG_INITIAL)){
        case this.CONFIG_ACCEPTED_PRELIMINAR : this.setAcceptedPre(); break;
        case this.CONFIG_REJECTED_PRELIMINAR : this.setRejectedPre(); break;
      }
    } else {
      switch (lane_control.data(this.CONFIG_INITIAL)){
        case this.CONFIG_ACCEPTED_FINAL : this.setAcceptedFinal(); break;
        case this.CONFIG_REJECTED_FINAL : this.setRejectedFinal(); break;
      }
    }
  };
}


/*
* Get current QC state of lanes and libraries for all position via ajax calls
*/
function getQcState() {
  //Preload images
  $('<img/>')[0].src = "/static/images/tick.png";
  $('<img/>')[0].src = "/static/images/cross.png";
  
  //Required to show error messages from the mqc process.
  jQuery("#results_summary").before('<ul id="ajax_status"></ul>'); 
  
  //Set up mqc controlers and link them to the individual lanes.
  $('.lane_mqc_control').each(function (i, obj) {
    obj = $(obj); //Wrap as an jQuery object.
    var c = new LaneMQCControl(i);
    c.linkControl(obj);
  });
}
