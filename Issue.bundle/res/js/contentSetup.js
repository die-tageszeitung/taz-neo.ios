/**
 * contentSetup
 *
 * Globale bekannte Objekte
 *	TAZAPI
 *	EPUBTAZ
 *	pageParams
 */
var contentSetup = (function() {
  "use strict";
  var fontsize		= 6;
  var pageEvent		= false;
  var contData		= false;
  var isContentVerbose	= true;
  var storageKey	= 'contData';
  var allFolder		= false;

  function getStorage() {
    var lsd = EPUBTAZ.getBookValue(storageKey);
    if (lsd)
      contData = JSON.parse(lsd);
    else
      contData = pageParams.contData;
    setupDom();
  }

  function setupDom() {
    EPUBTAZ.log("contentSetup.setupDom:");
    allFolder = true;
    for (var q=0; q<contData.length; q++) {			// Quelle oder Top
      setElnDisplay(contData[q].id, true);
      setDisplay(contData[q]);
      if (contData[q].data) {
	for (var p=0; p<contData[q].data.length; p++) {		// Seite
	  setElnDisplay(contData[q].data[p].id, true);
	  setDisplay(contData[q].data[p]);
	  if (contData[q].data[p].data) {
	    for (var t=0; t<contData[q].data[p].data.length; t++) {	// Fax, Text
	      setElnDisplay(contData[q].data[p].data[t].id, true);
	      EPUBTAZ.bookmarks.setMark(contData[q].data[p].data[t].id);
	    }
	  }
	}
      }
    }
  }

  function openDisplay(data, isOpen) {
    if (data && data.display) {
      if (isOpen)
	data.display = 'block';
      else
	data.display = 'none';
    }
  }

  function openFolder(isOpen) {
    EPUBTAZ.log("contentSetup.openFolder: ", isOpen);
    for (var q=0; q<contData.length; q++) {			// Quelle oder Top
      openDisplay(contData[q], isOpen);
      if (contData[q].data) {
	openDisplay(contData[q].data, isOpen);
	for (var p=0; p<contData[q].data.length; p++) {		// Seite
	  openDisplay(contData[q].data[p], isOpen);
	}
      }
    }
  }

  function setElnDisplay (eln, value) {
    var elm = document.getElementById(eln);
    var ico = document.getElementById('C'+ eln);
    var ut  = document.getElementById('ut_'+ eln);
    if (elm) {
      if (value) {
	elm.style.display = 'block';
	if (ico) ico.innerText = '\u2212';
      } else {
        allFolder = false;
	elm.style.display = 'none';
	if (ico) ico.innerText = '+';
      }
      if (ut) {
        if (EPUBTAZ.isContentVerbose)
	  ut.style.display = 'block';
	else
	  ut.style.display = 'none';
      }
    } else
      EPUBTAZ.log ("contentSetup.setDisplay: kann Element ", eln, " nicht finden");
  }

  function setDisplay (data) {
    var elm = document.getElementById('V'+data.id);
    var ico = document.getElementById('C'+data.id);
    if (elm) {
      elm.style.display = data.display;
      if (ico) {
	if (data.display == 'block')
	  ico.innerText = '\u2212';
	else {
	  ico.innerText = '+';
	  allFolder = false;
	}
      }
    }
    else
      EPUBTAZ.log ("contentSetup.setDisplay: kann Element ", 'V'+data.id, " nicht finden");
  }

  // --------------------- Render ---------------------

  return (function() {
    function oncklickQuelle(qu) {
      if (qu) {
        var qd = document.getElementById('V'+qu.id);
        var qm = document.getElementById('C'+qu.id);
	if (qd && qm) {
	  if (qd.style.display == 'none') {
	    qd.style.display = 'block';
	    qm.innerText = '\u2212';
	  } else {
	    qd.style.display = 'none';
	    qm.innerText = '+';
	    if (allFolder) {
	      allFolder = false;
	      viewFold(document.getElementById('unfoldButton'));
	    }
	  }
	  for (var q=0; q<contData.length; q++) {
	    if (contData[q].id == qu.id) {
	      contData[q].display = qd.style.display;
	    }
	  }
	}
      }
    }
    function oncklickPage(pa) {
      if (pa) {
        var pd = document.getElementById('V'+pa.id);
        var pm = document.getElementById('C'+pa.id);
	if (pd && pm) {
	  if (pd.style.display == 'none') {
	    pd.style.display = 'block';
	    pm.innerText = '\u2212';
	  } else {
	    pd.style.display = 'none';
	    pm.innerText = '+';
	    if (allFolder) {
	      allFolder = false;
	      viewFold(document.getElementById('unfoldButton'));
	    }
	  }
	  for (var q=0; q<contData.length; q++) {
	    if (contData[q].data) {
	      for (var p=0; p<contData[q].data.length; p++) {
		if (contData[q].data[p].id == pa.id) {
		  contData[q].data[p].display = pd.style.display;
		}
	      }
	    }
	  }
	}
      }
    }

    function oncklickMarker(elm) {
      for (var q=0; q<contData.length; q++) {				// Quelle
	if (contData[q].data) {
	  for (var p=0; p<contData[q].data.length; p++) {		// Seite
	    if (contData[q].data[p].data) {
	      for (var t=0; t<contData[q].data[p].data.length; t++) {	// Fax, Text
	        if (elm.id == 'mark_' + contData[q].data[p].data[t].id) {
		  var id = contData[q].data[p].data[t].id;
		  EPUBTAZ.bookmarks.toogle(id);
		  return;
		}
	      }
	    }
	  }
	}
      }
    }

    function saveStorage() {
      EPUBTAZ.log("contentSetup.saveStorage:");
      EPUBTAZ.setBookValue(storageKey, JSON.stringify(contData));
    }

    function link(link) {
      saveStorage();
      TAZAPI.startAnimation('in', 'SN');
      EPUBTAZ.internLink(link);
    }

    function toogleFold(button) {
      if (allFolder)
        openFolder(false);
      else
        openFolder(true);
      setupDom();
      viewFold(button);
    }

    function viewFold (button) {
      if (allFolder)
	button.innerText = '\u00a0\u2212\u00a0';
      else
	button.innerText = '\u00a0+\u00a0';
    }

    function toogleMark(button) {
      if (EPUBTAZ.viewMark) {
	EPUBTAZ.setViewMark('off');
      } else {
	EPUBTAZ.setViewMark('on');
      }
      viewMark(button);
    }

    function viewMark(button) {
      var ef = document.getElementById('unfoldButton');
      if (EPUBTAZ.viewMark) {
	if (ef) ef.style.display = 'none';
        button.innerText = 'Alle Einträge';
	for (var q=0; q<contData.length; q++) {			// Quelle
	  var vq = false;
	  setElnDisplay(contData[q].id, false);
	  setElnDisplay('V'+contData[q].id, false);
	  if (contData[q].data) {
	    for (var p=0; p<contData[q].data.length; p++) {		// Seite
	      var vp = false;
	      setElnDisplay(contData[q].data[p].id, false);
	      setElnDisplay('V'+contData[q].data[p].id, false);
	      if (contData[q].data[p].data) {
		for (var t=0; t<contData[q].data[p].data.length; t++) {	// Fax, Text
		  if (EPUBTAZ.bookmarks.isMark(contData[q].data[p].data[t].id)) {
		    if (!vq) {
		      vq = true;
		      setElnDisplay(contData[q].id, true);
		      setElnDisplay('V'+contData[q].id, true);
		    }
		    if (!vp) {
		      vq = true;
		      setElnDisplay(contData[q].data[p].id, true);
		      setElnDisplay('V'+contData[q].data[p].id, true);
		    }
		    setElnDisplay(contData[q].data[p].data[t].id, true);
		  } else
		    setElnDisplay(contData[q].data[p].data[t].id, false);
		}
	      }
	    }
	  }
	}
      } else {
	if (ef) ef.style.display = 'inline';
        button.innerText = 'markierte \u2297';
	setupDom();
      }
    }

    function resetWindow() {
      EPUBTAZ.log("contentSetup.resetWindow: isContentVerbose=", isContentVerbose, " conf=", EPUBTAZ.isContentVerbose);
      if (isContentVerbose !=  EPUBTAZ.isContentVerbose) {
        isContentVerbose = EPUBTAZ.isContentVerbose;
      }
      viewMark(document.getElementById('markButton'));
      viewFold(document.getElementById('unfoldButton'));
    }

    /**
     * init
     * Initalisiert das Objekt 
     */
    function init() {
      EPUBTAZ.log("contentSetup.init:");
      isContentVerbose = EPUBTAZ.isContentVerbose;
      getStorage();
      resetWindow();
      if ( window.onorientationchange )
	window.onorientationchange = contentSetup.resetWindow;
      else
	window.onresize = contentSetup.resetWindow;
      var r = EPUBTAZ.referrer;
      if (r && r != 'content.xhtml') {
	window.location.hash = '#' + r;
	window.scrollBy(0, -30);
      }
    }

    // return public interface
    return {
      oncklickQuelle	: oncklickQuelle,
      oncklickPage	: oncklickPage,
      oncklickMarker	: oncklickMarker,
      link		: link,
      saveStorage	: saveStorage,
      toogleMark	: toogleMark,
      toogleFold	: toogleFold,
      resetWindow	: resetWindow,
      init		: init
    }
  } ());
}());

function setupContentWindow() {
  EPUBTAZ.init({
    render	: contentSetup.resetWindow,
    noPosition	: true
  });
  contentSetup.init();
  TAZAPI.onHideDirectory = function () {
    contentSetup.saveStorage();
  }
  TAZAPI.pageReady();
}
