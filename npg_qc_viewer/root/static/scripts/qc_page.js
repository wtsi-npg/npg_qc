/*
 */
/* globals $: false, define: false */
'use strict';
define(['jquery'], function (jQuery) {
  var _reRunLane   = /(?:(?:for (run) ([0-9]+))|(?:for (runs) ([0-9]+) lanes ([0-9]+))) \(run/;
  var _reRunStatus = /\(run [0-9]+ status: ((?:[\S]+)(?:\s[\S]+){2}), taken by ([\S]+)\)$/;
  
  var _reLoggedUser = /^Logged in as ([a-zA-Z0-9]+)(?:[\s]{1}(?:\((mqc)\)))?$/i; // [1] username, [2] (mqc)

  var _parseRunLane = function(titleString) {
    if ( typeof titleString !== 'string' ) {
      throw new Error('Invalid arguments');
    }

    var matchRunLane = _reRunLane.exec(titleString);
    var isRunPage = null;

    if ( matchRunLane != null ) {
      if( matchRunLane.constructor === Array && matchRunLane.length > 1 ) {
        if ( typeof matchRunLane[1] !== 'undefined' ) {
          isRunPage = true;
        } else if ( typeof matchRunLane[3] !== 'undefined' ) {
          isRunPage = false;
        }
      }
    }

    return {
      isRunPage: isRunPage
    };
  };
  
  var _parseRunStatus = function(titleString) {
    if ( typeof titleString !== 'string' ) {
      throw new Error('Invalid arguments');
    }

    var matchRunStatus = _reRunStatus.exec(titleString);
    var runStatus = null, takenBy = null;

    if ( matchRunStatus != null &&
         matchRunStatus.constructor === Array &&
         matchRunStatus.length == 3 ) {
      runStatus = matchRunStatus[1].replace(/^\s+/g,'');
      takenBy   = matchRunStatus[2];
    }

    return {
      runStatus: runStatus,
      takenBy:   takenBy
    };
  };

  var _parseLoggedUser = function(loggedUserString) {
    if ( typeof loggedUserString !== 'string' ) {
      throw new Error('Invalid arguments');
    }
    var username = null, role = null;
    
    var matchLoggedUser = _reLoggedUser.exec(loggedUserString);
    if (matchLoggedUser != null) {
      if (matchLoggedUser.constructor === Array && matchLoggedUser.length > 1) {
        username = matchLoggedUser[1];
        if (matchLoggedUser.length === 3) {
          role = matchLoggedUser[2];
        }
      }
    }
    
    return {
      username: username, //
      role:     role //
    };
  };

  var pageForMQC = function() {
    var isPageForMQC = false, isRunPage = null;
    
    var loggedUserString = $('#header h1 span.rfloat').text();
    var loggedUserData = _parseLoggedUser(loggedUserString);
    if ( loggedUserData.username != null &&
         loggedUserData.role === 'mqc' ) {
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
    _parseRunLane: _parseRunLane,
    _parseRunStatus: _parseRunStatus,
    _parseLoggedUser: _parseLoggedUser,
    pageForMQC: pageForMQC
  };
});

