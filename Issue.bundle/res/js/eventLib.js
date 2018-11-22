/*
 * Objekt für Tastatur und Touch-Events
 */

var tazAppEvent = (function() {
  "use strict";

  var link	= false;
  var leftTab	= false;
  var rightTab	= false;
  var tabMargin	= 40;

  function isLink(e) {
    while (e) {
//      EPUBTAZ.log ("tazAppEvent.isLink: e=", e.nodeName);
      if (e.nodeType == 1) {
	if (e.nodeName.toLowerCase() == 'a') {
	  var h = e.href;
//	  EPUBTAZ.log ("tazAppEvent.isLink: h=", h);
	  if (h.search(/^javascript:/) != -1) 
	    link = h.replace(/^javascript:/, '');
	  else if (h.search(/^EPUBTAZ/) == -1) 
	    link = "EPUBTAZ.externLink('" + h + "')";
	  else
	    link = h;
	  return true;
	}
      }
      e = e.parentNode;
    }
    return false;
  }

  function isClickElement(x, y) {
    var e = document.elementFromPoint(x - window.pageXOffset, y - window.pageYOffset);
    if (e && e.nodeType == 1 && isLink(e))
      return true;
    else
      return false;
  }

  function iosTap (x, y, isAction) {
    EPUBTAZ.log ("tazAppEvent.iosTap: x=", x, " y=", y, " isAction=", isAction);
    link     = false;
    var func = false;
    isClickElement(x, y);
    EPUBTAZ.log ("tazAppEvent.iosTap: link=", link);
    if (link) {
      if (isAction) {
	try {
	  eval(link);
	} catch (e) {
	  EPUBTAZ.log ("tazAppEvent.touchStart: Fehler Link: ", link, " e=", e);
	}
      }
      return true;
    }
    if (x < tabMargin && leftTab) {
      if (isAction && EPUBTAZ.isPaging) return leftTab();
      return true;
    } else if ( x > window.innerWidth - tabMargin && rightTab) {
      if (isAction && EPUBTAZ.isPaging) return rightTab();
      return true;
    }
    return false;
  }

  function androidTap (x, y) {
    EPUBTAZ.log ("tazAppEvent.androidTap: x=", x, " y=", y);
    link     = false;
    var func = false;
    isClickElement(x + window.pageXOffset, y + window.pageYOffset);
    EPUBTAZ.log ("tazAppEvent.androidTap: link=", link);
    if (link) {
      try {
	eval(link);
      } catch (e) {
	EPUBTAZ.log ("tazAppEvent.androidTap: Fehler Link: ", link, " e=", e);
      }
      return true;
    }
    if (x < tabMargin && leftTab && EPUBTAZ.isPaging) {
      return leftTab();
    } else if ( x > window.innerWidth - tabMargin && rightTab && EPUBTAZ.isPaging) {
      return rightTab();
    }
    return false;
  }

  return (function() {

    function init(params) {
      leftTab = rightTab = false;
      if (params) {
	if (params.leftTab	) leftTab	= params.leftTab;
	if (params.rightTab	) rightTab	= params.rightTab;
      }
      var b = Math.round(window.innerWidth / 4);
      if (b > tabMargin) tabMargin = b;
      if (EPUBTAZ.isIos) {
	EPUBTAZ.setGesture ({
	  tap        : iosTap,
	});
      } else {
	$( window ).on( "click", function(e) {
	  e.preventDefault();
	  // e.stopImmediatePropagation();
	  androidTap(e.pageX - window.pageXOffset, e.pageY - window.pageYOffset);
	  }
	);
      }
    }

    return {
      init		: init
    }
  } ());
}()); // tazAppEvent
