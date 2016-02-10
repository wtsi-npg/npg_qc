/**
 * Module with abstraction of css styles for QC outcomes. It builds the css
 * styles and adds them to the <head> during loading. Then it provides
 * functionality for adding these style classes to elements.
 */
/* globals $: false, define: false */
'use strict';
define(['jquery'], function () {
  var _outcomeStyleClassToStyle = {
    qc_outcome_accepted_final: "{ background: #b5daff none; }",
    qc_outcome_accepted_preliminary: "{ background: #ffffff repeating-linear-gradient(45deg, #B5DAFF, #B5DAFF 10px, #FFFFFF 10px, #FFFFFF 20px); }",
    qc_outcome_rejected_final: "{ background: #F99389 none; }",
    qc_outcome_rejected_preliminary: "{ background: #ffffff repeating-linear-gradient(45deg, #FFDDDD, #FFDDDD 10px, #FFFFFF 10px, #FFFFFF 20px); }",
    qc_outcome_undecided: "{ background: #ffffff none; }",
    qc_outcome_undecided_final: "{ background: #ffffff none; }"
  };

  var _isValidStyleClass = function (styleClass) {
    return (Object.keys(_outcomeStyleClassToStyle).indexOf(styleClass) != -1);
  };

  var removePreviousQCOutcomeStyles = function (element) {
    if (typeof element === 'undefined') {
      throw 'Element cannot be undefined.';
    }
    element.removeClass(function (index, css) {
      return (css.match (/qc_outcome[a-zA-Z_]+/gi) || []).join(' ');
    });
  };

  var displayElementAs = function( element, qcOutcome ) {
    if (typeof element === 'undefined') {
      throw 'Element cannot be undefined.';
    }
    if (typeof qcOutcome === 'undefined') {
      throw 'qcOutcome cannot be undefined.';
    }

    var newClass = 'qc_outcome_' + qcOutcome.toLowerCase();
    newClass = newClass.replace(/ /g, '_');

    if (_isValidStyleClass(newClass)) {
      //TODO Consider only remove/add if object does not have the new class
      removePreviousQCOutcomeStyles(element);
      element.addClass(newClass);  
    } else {
      throw "Can't find corresponding style for QC outcome " + qcOutcome + ".";
    }
  };

  var _declareStyles = function() {
    var style_id = 'qc_css_styles_code';
    if ($('#' + style_id).length === 0) { //Prevent appending stylesheet more than once
      var styleSheetCode = "<style type='text/css' id='" + style_id + "'>";
      var outcomeStyleClasses = Object.keys(_outcomeStyleClassToStyle);
      for(var i = 0; i < outcomeStyleClasses.length; i++) {
        var outcomeStyleClass = outcomeStyleClasses[i];
        styleSheetCode += '.' +
                          outcomeStyleClass +
                          ' ' +
                          _outcomeStyleClassToStyle[outcomeStyleClass] +
                          "\n";
      }
      styleSheetCode += "</style>";
      $(styleSheetCode).appendTo("head");
    }
  };

  _declareStyles();
  
  return {
    displayElementAs: displayElementAs,
    removePreviousQCOutcomeStyles: removePreviousQCOutcomeStyles,
  };
});
