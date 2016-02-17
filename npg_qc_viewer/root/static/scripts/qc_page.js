/*
 */
/* globals $: false, define: false */
'use strict';
define(['jquery'], function (jQuery) {
  var _reTitle = /^NPG SeqQC v[\w\.]+: Results(?: \(all\))? for (run[s]?) ([0-9]+)(?: lanes ([0-9]))? \(run [0-9]+ status:(?: [a-zA-Z0-9]+){3}, taken by ([a-zA-Z0-9]+)\)$/;
  var _reRunPage = //;
  var _reRunStatus = /\(run [0-9]+ status:(?: [a-zA-Z0-9]+){3}, taken by ([a-zA-Z0-9]+)\)$/;
  
  var _reLoggedUser = /^Logged in as ([a-zA-Z0-9]+)(?:[\s]{1}(?:\((mqc)\)))?$/i; // [1] username, [2] (mqc)

  var _parseTitle = function(titleString) {
    if ( typeof titleString !== 'string' ) {
      throw new Error('Invalid arguments');
    }
  
    var match = _reTitle.exec(titleString);
    var isRunPage = null, idRun = null, position = null, runStatus = null, takenBy = null;

    if (match != null) {
      if(match.constructor === Array && match.length > 2) {
        if (match[1].indexOf('runs') === -1) {
          isRunPage = true;
          idRun     = match[2];
          runStatus = match[4].replace(/^\s+/g,'');
          takenBy   = match[5];
        } else if (match[1].indexOf('runs') === 0) {
          isRunPage = false;
          idRun     = match[2];
          position  = match[3];
          runStatus = match[4].replace(/^\s+/g,'');
          takenBy   = match[5];
        }
      }
    }
    
    return {
      isRunPage: isRunPage,
      idRun:     idRun,
      position:  position,
      runStatus: runStatus, //
      takenBy:   takenBy //
    };
  };

  var _parseLoggedUser = function(loggedUserString) {
    if ( typeof loggedUserString !== 'string' ) {
      throw new Error('Invalid arguments');
    }
    var loggedUser = null, loggedUserRole = null;
    
    var match = _reLoggedUser.exec(loggedUserString);
    if (match != null) {
      if (match.constructor === Array && match.length > 0) {
        loggedUser = match[1];
        if (match.length === 3) {
          loggedUserRole = match[2];
        }
      }
    }
    
    return {
      loggedUser:     loggedUser, //
      loggedUserRole: loggedUserRole //
    };
  };

  var pageForMQC = function() {
    var isPageForMQC = false, isRunPage = null;
    
    var loggedUserString = $('#header h1 span.rfloat').text();
    var loggedUserData = _parseLoggedUser(loggedUserString);
    if (loggedUserData.loggedUser != null && loggedUserData.loggedUserRole === 'mqc') {
      var pageTitleString = $('title').text();
      var runStatusData = _parseRunStatus(pageTitleString);
      if ( loggedUserData.role === 'mqc' &&
           ( runStatusData.runStatus === 'qc in progress' ||
             runStatusData.runStatus === 'qc on hold') &&
           loggedUserData.username === runStatusData.takenBy ) {
        isPageForMQC = true;
        var runInfo = _parseRunLane(pageTitleString);
        isRunPage = runInfo.isRunPage;
      }
    }
    
    return {
      isPageForMQC: isPageForMQC,
      isRunPage:   isRunPage
    };
  };

  return {
    _parseTitle: _parseTitle,
    _parseLoggedUser: _parseLoggedUser,
    pageForMQC: pageForMQC
  };
});

