// var tazAppIsDebug = true;


TAZAPI.onConfigurationChanged = function (name, value) {
  EPUBTAZ.log("TAZAPI.onConfigurationChanged: name=", name, " value=", value);
  switch (name) {
    case "fontsize":
      return EPUBTAZ.setFontsize(value);
      break;
    case "colsize":
      return EPUBTAZ.setColsize(value);
      break;
    case "theme":
      return EPUBTAZ.setTheme(value);
      break;
    case "isScroll":
      return EPUBTAZ.setIsScroll(value, false);
      break;
    case "FullScreen":
      return EPUBTAZ.setFullScreen(value);
      break;
    case "ContentVerbose":
      return EPUBTAZ.setContentVerbose(value);
      break;
    case "isScrollToNext":
      return EPUBTAZ.setScrollToNext(value);
      break;
    case "isJustify":
      return EPUBTAZ.setJustify(value);
      break;
    case "isNoPaging":
      return EPUBTAZ.setNoPaging(value);
      break;
    case "isPaging":
      return EPUBTAZ.setPaging(value);
      break;
    case "isSocial":
      return EPUBTAZ.setIsSocial(value);
      break;
    case "isFoot":
      return EPUBTAZ.setIsFoot(value);
      break;
    case "FullScreen":
      return EPUBTAZ.setFullScreen(value);
      break;
    default:
      return false;
  }
}

TAZAPI.onGesture = function (name, x, y) {
  return EPUBTAZ.onGesture(name, x, y);
}

TAZAPI.willHandleTap = function (x, y) {
  return EPUBTAZ.willHandleTap(x, y);
}

TAZAPI.onShowDirectory = function () {
  EPUBTAZ.showDirectory();
}

if (typeof TAZAPI.getAbsoluteResourcePath === 'function') {
	TAZAPI.resourcePathPrefix = TAZAPI.getAbsoluteResourcePath();
}
else {
	TAZAPI.resourcePathPrefix = "";
}

// -------------------------- EPUBTAZ ------------------------

/**
 * Globaler Handler für das ePub
 */

var EPUBTAZ = (function() {
  "use strict";
  var pageName		= false;
  var pageId		= false;
  var position		= 0;
  var fontsize		= 10;
  var colsize		= 0.5;
  var theme		= 'normal';
  var version		= 0;
  var bookId		= false;
  var referrer		= false;
  var isDebug		= false;
  var isEmpty		= false;
  var debugUrl		= false;
  var viewMark		= false;
  var render		= false;
  var isFullScreen	= false;
  var pixelRatio	= 1;
  var isContentVerbose	= true;
  var themeStyle	= false;
  var themeScroll	= false;
  var callbackVal	= false;
  var callbackSet	= false;
  var lineHight		= false;
  var isIos		= false;
  var isScrollToNext	= true;
  var isJustify		= false;
  var isPaging		= true;
  var isChangeArtikel	= false;

  var swipeUp		= false;
  var swipeDown		= false;
  var swipeLeft		= false;
  var swipeRight	= false;
  var tap		= false;
  var isScroll		= true;
  var wasScroll		= false;
  var bgColorNormal	= '#FFFFFF';
  var bgColorSepia	= '#FAF7EF';
  var bgColorNight	= '#000000';
               
  var bookmarks = (function() {
    var textList	= false;
    var markList	= false;
    var activeText	= '\u2297';
    var passivText	= '\u2295';
    var activeColor	= '#961d2a';
    var passivColor	= '#666';
    var activeImage	= false;
    var passivImage	= false;

    function storageKey () {
      return '/'+bookId+'/bookmarks';
    }

    function read () {
      EPUBTAZ.log ("EPUBTAZ.bookmarks.read");
      if (!textList) {
	var req = new XMLHttpRequest();
	req.open("GET", 'bookmarks.json', false);	// false = synchron
	req.send(null);
	if (req.readyState === 4) {
	  var ret = req.responseText;
	  try {
	    textList = JSON.parse(ret);
	  } catch (e) {
	    EPUBTAZ.log("EPUBTAZ.bookmarks.read: Error:", e, " Data:", ret);
	  }
	}
	if (textList)
	  EPUBTAZ.log("EPUBTAZ.bookmarks.read: textList");
	else
	  return;
      }
      if (!markList) {
        var sml = false;
        TAZAPI.getBookmarks(EPUBTAZ.setCallbackVal, storageKey());
        while (!callbackSet)
          EPUBTAZ.log("EPUBTAZ.bookmark.read: ######################## kein callBack");
	if (callbackSet) {
	  EPUBTAZ.log("EPUBTAZ.bookmark.read: callbackVal:", callbackVal);
	  /*
	  try {
	    sml = JSON.parse(callbackVal);
	  } catch (e) {
	    EPUBTAZ.log("EPUBTAZ.bookmarks.read: Error:", e, " Data:", callbackVal);
	  }
	  */
	  sml = callbackVal;
	}
	if (sml)
	  EPUBTAZ.log("EPUBTAZ.bookmarks.read: markList");
	else
	  sml = new Object();
	markList = new Object();
	for(var i = 0; i < textList.length; i++)
	  markList[textList[i]] = sml[textList[i]]?true:false;
	EPUBTAZ.log("EPUBTAZ.bookmarks.read: markList:", markList);
      }
    }

    return (function() {

      function next (id) {
        read();
        var i = textList.indexOf(id);
	if (i) {
	  for (i; i<textList.length; i++) {
	    if (markList[textList[i]]) return textList[i];
	  }
	}
	return false;
      }

      function prev (id) {
        read();
        var i = textList.indexOf(id);
	if (i) {
	  for (i; i >= 0; i--) {
	    if (markList[textList[i]]) return textList[i];
	  }
	}
	return false;
      }

      /**
       * isMark 
       *
       * @param string id	id der Bookmark
       *
       * @return bool	Ist markiert
       */
      function isMark (id) {
        read();
	return (textList && markList &&  markList[id]);
      }

      function setMark (id) {
        read();
	var elm = document.getElementById('mark_'+id);
	if (elm) {
	  if (activeImage && passivImage) {
	    if (isMark(id))
	      elm.src = activeImage;
	    else
	      elm.src = passivImage;
	    elm.style.width  = EPUBTAZ.fontsize + 'px';
	    elm.style.height = EPUBTAZ.fontsize + 'px';
	  } else if (activeText && passivText) {
	    if (isMark(id)) {
	      elm.style.color = activeColor;
	      elm.innerText   = activeText;
	    } else {
	      elm.style.color = passivColor;
	      elm.innerText   = passivText;
	    }
	  }
	} else
	  EPUBTAZ.log ("EPUBTAZ.bookmarks.setMark: kann Element ", 'mark_'+id, " nicht finden");
      }

      function setupMarks () {
        var bl = document.getElementsByName("bookmark");
	if (bl) {
	  for (var i=0; i<bl.length; i++)
	    setMark(bl[i].id.substr(5));
	}
      }

      /**
       * toogle 
       *
       * @param string id	id der Bookmark
       *
       * @return bool	Ist markiert
       */
      function toogle (id) {
	EPUBTAZ.log ("EPUBTAZ.bookmarks.toogle: id=", id);
        read();
	if (markList) {
	  markList[id] = !markList[id];
	  TAZAPI.setBookmark(id, markList[id], storageKey(), markList);
	  setMark(id);
	}
      }

      function init (param) {
	EPUBTAZ.log ("EPUBTAZ.bookmarks.init: ", param);
        read();
        if (param) {
	  if (param.activeText ) activeText  = param.activeText;
	  if (param.passivText ) passivText  = param.passivText;
	  if (param.activeColor) activeColor = param.activeColor;
	  if (param.passivColor) passivColor = param.passivColor;
	  if (param.activeImage) activeImage = param.activeImage;
	  if (param.passivImage) passivImage = param.passivImage;
	}
      }

      return {
	get markList()	{ return markList; },
	setupMarks	: setupMarks,
	setMark		: setMark,
        toogle		: toogle,
        isMark		: isMark,
        next		: next,
        prev		: prev,
	init		: init
      }
    } ());
  } ());

  return (function() {

    /**
     * nextPage
     *
     * nächste Seite je nach dem ob direkt oder über Bookmarks
     *
     * @param string	next	Nächste ohne Bookmarks
     *
     * @return string	nextPage
     */
    function nextPage (next) {
      if (viewMark) {
        return bookmarks.next(next);
      } else
        return next;
    }

    /**
     * prevPage
     *
     * nächste Seite je nach dem ob direkt oder über Bookmarks
     *
     * @param string	prev	Nächste ohne Bookmarks
     *
     * @return string	prevPage
     */
    function prevPage (prev) {
      if (viewMark) {
        return bookmarks.prev(prev);
      } else
        return prev;
    }

    /**
     * setBookValue
     *
     * Wert setzen
     *
     * @param string	path
     * @param string	value
     *
     * @return bool	ok
     */
    function setBookValue (path, value) {
      log("EPUBTAZ.setBookValue: path=", path, " value=", value);
      if (!bookId) bookId = 'noId';
      return TAZAPI.setValue('/'+bookId+'/'+path, value);
    }
          
    /**
     * Test Callback
     */
    function setCallbackVal (val) {
      callbackSet = true;
      callbackVal = val;
    }
          
    /**
     * Test Callback
     */
    function myGetValue (val) {
        callbackSet = false;
        TAZAPI.getValue(val, EPUBTAZ.setCallbackVal);
        while (!callbackSet)
          log("EPUBTAZ.myGetValue: ######################## kein callBack");
        return callbackVal;
    }
          
    /**
     * Test myGetConfiguration
     */
    function myGetConfiguration (val) {
      callbackSet = false;
      TAZAPI.getConfiguration(val, setCallbackVal);
      while (!callbackSet)
        log("EPUBTAZ.myGetConfiguration: ######################## kein callBack");
      return callbackVal;
    }


    /**
     * getBookValue
     *
     * Wert für diese Ausgabe lesen
     * Name/Werte-Paare wobei der Name ein Pfad ist, 
     * der bei Daten zu einem ePub immer mit /bookId beginnt
     *
     * @param string	path
     *
     * @return string	value oder null
     */
    function getBookValue(path) {
      log("EPUBTAZ.getBookValue: path=", path);
      if (!bookId) bookId = 'noId';
      return myGetValue('/'+bookId+'/'+path);
    }

    /**
     * setDebug
     *
     * schaltet Debug ein oder aus und setzt optional die Debug URL
     *
     * @param bool	value	Schalter für Debug
     * @param string	url	optional Debug URL
     */
    function setDebug (value /*, url */) {
      isDebug = value;
      if (arguments.length > 1) debugUrl = arguments[1];
      var opt = "off";
      if (isDebug) opt = "on";
      return setBookValue('isDebug', opt);
    }

    /**
     * getDebug
     * @param int	level
     *
     */
    function getDebug (level) {
      if (arguments.length > 0)
	return (level > 0 && isDebug);
      else
        return isDebug;
    }

    /*
     * log
     *
     * Logfunktion
     *
     * @pram var arg log	loggt alle Argumente
     *
     */
    function log (/* ... */) {
      if ( isDebug ) {
	var req = false;
	var str = '';
	for (var i = 0; i < arguments.length; i++) {
	  if (arguments[i] === undefined)
	    str += 'undefined';
	  else if (arguments[i] === null)
	    str += 'null';
	  else
	    str += arguments[i].toString();
	}
	TAZAPI.netLog(str);
      }
    }

    /**
     * setViewMark
     *
     * schaltet die Navigation nach Bookmarks ein und aus
     *
     * @return bool	status
     */
    function setViewMark(value) {
      log("EPUBTAZ.setViewMark: value=", value);
      if (value == 'on') {
        viewMark = true;
	setBookValue("viewMark", 'on');
	return true;
      }
    }

    /**
     * setViewMark
     *
     * schaltet die Navigation nach Bookmarks ein und aus
     *
     * @return bool	status
     */
    function setViewMark(value) {
      log("EPUBTAZ.setViewMark: value=", value);
      if (value == 'on') {
        viewMark = true;
	setBookValue("viewMark", 'on');
	return true;
      } else if (value == 'off') {
        viewMark = false;
	setBookValue("viewMark", 'off');
        return true;
      } else
        return false;
    }

    function screenFontsize () {
      // return 8 + fontsize * 2;
      return 8 + fontsize;
    }

    function setWindowFontsize () {
      log("EPUBTAZ.setWindowFontsize:");
      var body = document.getElementsByTagName('body');
      var html = document.getElementsByTagName('html');
      if (body && body.length && html && html.length) {
	log ("EPUBTAZ.setWindowFontsize: fontsizePx=", screenFontsize(), " fontsize=", fontsize);
	body[0].style.fontSize = screenFontsize() + "px";
	html[0].style.fontSize = screenFontsize() + "px";
	lineHight = parseFloat(window.getComputedStyle(body[0]).getPropertyValue("line-height"));
	if (render) render();
      } else
	log("EPUBTAZ.setWindowFontsize: Ein benötigtes Element feht");
    }

    /**
     * setFontsize
     *
     * setzt die Schriftgröße, in Schritte 0 - 20
     *
     * @param int/string	neue Schriftgröße 
     *
     * @return bool	ok
     */
    function setFontsize(value) {
      log("EPUBTAZ.setFontsize: value=", value);
      var ret = false;
      var oldFontSize = fontsize;
      if (typeof (value) == 'string') {
        if ( (value = parseFloat(value)) === NaN) return false;
      }
      value = Math.round(value);
      if (value > 20)
        fontsize = 20;
      else if (value <  0)
        fontsize =  0;
      else {
	fontsize = value;
	ret = true;
      }

      if (ret) setWindowFontsize()
      TAZAPI.setConfiguration("fontsize", fontsize.toString());
      return ret;
    }

    /**
     * incFontsize
     *
     * setzt die Schriftgröße in Schritten hoch oder runter
     *
     */
    function incFontsize(step) {
      if (step)
        setFontsize(fontsize+1);
      else
        setFontsize(fontsize-1);
    }

    // Spaltenbeite

    function columnCount () {
      /*
      if (isScroll) return 1;
      if (window.innerWidth > window.innerHeight)
        return 3;
      else
	return 2;
      */

      // Zeichen pro Seite Schätzeisen min 20 Zeichen pro Spalte
      var cPage = Math.round(window.innerWidth / screenFontsize()) * 2;
      var maxCols = Math.round(cPage / 20);
      var cols = maxCols - Math.round(colsize * (maxCols-1));
      EPUBTAZ.log ("EPUBTAZ.columnCount: ", cols, " maxCols=", maxCols, " colsize=", colsize);
      return cols;
    }

    /**
     * setColsize
     *
     * setzt die Spaltenbeite, 0 - 1.0
     *
     * @param int/string	neue Spaltenbreite 
     *
     * @return bool	ok
     */
    function setColsize(value) {
      var ret = false;
      if (isScroll) return false;
      var oldColSize = colsize;
      if (typeof (value) == 'string') {
        if ( (value = parseFloat(value)) === NaN) {
	  log("EPUBTAZ.setColsize: Fehlerhafter Wert value=", value);
	  return false;
	}
      }
      if (value > 1.0)
        colsize = 1.0;
      else if (value <  0.0)
        colsize =  0.0;
      else {
	colsize = value;
	ret = true;
      }
      log("EPUBTAZ.setColsize: value=", value, " old=", oldColSize);
      if (oldColSize != colsize && render) {
	render();
      }
      TAZAPI.setConfiguration("colsize", colsize.toString());
      return ret;
    }

    /**
     * incColsize
     *
     * setzt die Spaltenbreite in Schritten hoch oder runter
     *
     */
    function incColsize(step) {
      if (step)
        setColsize(colsize+0.1);
      else
        setColsize(colsize-0.1);
    }

    // Themen 
    function isThemePage() {
      return (pageParams.tazAppPageType == 'artikel' || pageParams.tazAppPageType == 'wait');
    }

    function setThemeNormal() {
      theme = 'normal';
      TAZAPI.setConfiguration("theme", theme);
      if (isThemePage()) {
        var headID = document.getElementsByTagName("head")[0];         
        var style = document.createElement("link");
	style.setAttribute('type','text/css');
	style.rel = 'stylesheet';
	style.href = TAZAPI.resourcePathPrefix+'res/css/themeNormal.css';
	style.media = 'screen';
	if (themeStyle) {
	  headID.replaceChild(style, themeStyle);
	} else
	  headID.appendChild(style);
	themeStyle = style;
        var body = document.getElementsByTagName('body');
	if (body) body[0].style.backgroundColor = bgColorNormal;
      }
    }
    function setThemeSepia() {
      theme = 'sepia';
      TAZAPI.setConfiguration("theme", theme);
      if (isThemePage()) {
        var headID = document.getElementsByTagName("head")[0];         
        var style = document.createElement("link");
	style.setAttribute('type','text/css');
	style.rel = 'stylesheet';
	style.href = TAZAPI.resourcePathPrefix+'res/css/themeSepia.css';
	style.media = 'screen';
	if (themeStyle) {
	  headID.replaceChild(style, themeStyle);
	} else
	  headID.appendChild(style);
	themeStyle = style;
        var body = document.getElementsByTagName('body');
	if (body) body[0].style.backgroundColor = bgColorSepia;
      }
    }
    function setThemeNight() {
      theme = 'night';
      TAZAPI.setConfiguration("theme", theme);
      if (isThemePage()) {
        var headID = document.getElementsByTagName("head")[0];         
        var style = document.createElement("link");
	style.setAttribute('type','text/css');
	style.rel = 'stylesheet';
	style.href = TAZAPI.resourcePathPrefix+'res/css/themeNight.css';
	style.media = 'screen';
	if (themeStyle) {
	  headID.replaceChild(style, themeStyle);
	} else
	  headID.appendChild(style);
	themeStyle = style;
        var body = document.getElementsByTagName('body');
	if (body) body[0].style.backgroundColor = bgColorNight;
      }
    }

    /**
     * setTheme
     *
     * setzt das Thema: 'normal', 'sepia', 'night'
     *
     * @param int/string	neues Thema 
     *
     * @return bool	ok
     */
    function setTheme(value) {
      log("EPUBTAZ.setTheme: value=", value);
      var ret = false;
      switch (value) {
        case 'normal':
	  if (theme != value) setThemeNormal();
	  ret = true;
        case 'sepia':
	  if (theme != value) setThemeSepia();
	  ret = true;
        case 'night':
	  if (theme != value) setThemeNight();
	  ret = true;
      }
      /* ###
      if (ret) {
        var body = document.getElementsByTagName('body');
	if (body) {
	  TAZAPI.setConfiguration('bgColor', body[0].style.backgroundColor);
	}
      }
      */
      return ret;
    }

    /**
     * setIsFoot
     *
     * Kompatibilität 
     *
     */
    function setIsFoot(value) {
      return true;
    }

    /**
     * setIsSocial
     *
     * Kompatibilität 
     *
     */
    function setIsSocial(value) {
      return true;
    }

    /**
     * setIsScroll
     *
     * Schaltet das Scrollen ein oder aus: 'on', 'off'
     *
     * @param int/string	Zustand
     *
     * @return bool	ok
     */
    function setIsScroll(value, isFirst) {
      log("EPUBTAZ.setIsScroll: value=", value, " isScroll=", isScroll, " pageName=", pageName);
      if (value == 'on') {
        if (!isScroll) {
	  isScroll = true;
	  colsize = 1.0;
	  log("EPUBTAZ.setIsScroll: change value=", value);
	  TAZAPI.setConfiguration("isScroll", 'on');
	  if (!isFirst) TAZAPI.openUrl(pageName + "?position=" + position);
	}
      } else {
        if (isScroll) {
	  isScroll = false;
	  var g;
	  if ( (g = myGetConfiguration("colsize")) && parseFloat(g) != NaN) colsize = parseFloat(g);
	  log("EPUBTAZ.setIsScroll: change value=", value);
	  TAZAPI.setConfiguration("isScroll", 'off');
	  if (!isFirst) TAZAPI.openUrl(pageName + "?position=" + position);
	}
      }
      return true;
    }

    /**
     * setFullScreen
     *
     * Schaltet den FullScreen ein oder aus: 'on', 'off'
     *
     * @param int/string	Zustand
     *
     * @return bool	ok
     */
    function setFullScreen(value) {
      log("EPUBTAZ.setFullScreen: value=", value);
      if (value == 'on') {
        if (!isFullScreen) {
	  isFullScreen = true;
	  TAZAPI.setConfiguration("FullScreen", 'on');
	  if (render) {
	    render();
	  }
	}
	return true;
      } else if (value == 'off') {
        if (isFullScreen) {
	  isFullScreen = false;
	  TAZAPI.setConfiguration("FullScreen", 'off');
	  if (render) {
	    render();
	  }
	}
	return true;
      } else
	return false;
    }

    /**
     * setScrollToNext
     *
     * Schaltet das Scrollen zum nächsten Artikel ein oder aus: 'on', 'off'
     *
     * @param int/string	Zustand
     *
     * @return bool	ok
     */
    function setScrollToNext(value) {
      log("EPUBTAZ.setScrollToNext: value=", value);
      if (value == 'on') {
	isScrollToNext = true;
	TAZAPI.setConfiguration("isScrollToNext", 'on');
	return true;
      } else if (value == 'off') {
	isScrollToNext = false;
	TAZAPI.setConfiguration("isScrollToNext", 'off');
	return true;
      } else
	return false;
    }

    /**
     * setJustify
     *
     * Schaltet den Blocksatz ein oder aus: 'on', 'off'
     *
     * @param int/string	Zustand
     *
     * @return bool	ok
     */
    function setJustify(value) {
      log("EPUBTAZ.setJustify: value=", value, " pageName=", pageName, " position=", position);
      if (value == 'on' && !isJustify) {
	isJustify = true;
	TAZAPI.setConfiguration("isJustify", 'on');
	TAZAPI.openUrl(pageName + "?position=" + position);
	return true;
      } else if (value == 'off' && isJustify) {
	isJustify = false;
	TAZAPI.setConfiguration("isJustify", 'off');
	TAZAPI.openUrl(pageName + "?position=" + position);
	return true;
      } else
	return false;
    }

    /**
     * setNoPaging iOS
     *
     * Schaltet das Blättern mit einem Tab auf die Ränder ein oder aus: 'on', 'off'
     *
     * @param int/string	Zustand
     *
     * @return bool	ok
     */
    function setNoPaging(value) {
      log("EPUBTAZ.setNoPaging: value=", value);
      if (value == 'off') {
	isPaging = true;
	TAZAPI.setConfiguration("isNoPaging", 'off');
	return true;
      } else if (value == 'on') {
	isPaging = false;
	TAZAPI.setConfiguration("isNoPaging", 'on');
	return true;
      } else
	return false;
    }

    /**
     * setPaging Android
     *
     * Schaltet das Blättern mit einem Tab auf die Ränder ein oder aus: 'on', 'off'
     *
     * @param int/string	Zustand
     *
     * @return bool	ok
     */
    function setPaging(value) {
      log("EPUBTAZ.setPaging: value=", value);
      if (value == 'on') {
	isPaging = true;
	TAZAPI.setConfiguration("isPaging", 'on');
	return true;
      } else if (value == 'off') {
	isPaging = false;
	TAZAPI.setConfiguration("isPaging", 'off');
	return true;
      } else
	return false;
    }

    /**
     * setContentVerbose
     *
     * Schaltet den ContentVerbose ein oder aus: 'on', 'off'
     *
     * @param int/string	Zustand
     *
     * @return bool	ok
     */
    function setContentVerbose(value) {
      log("EPUBTAZ.setContentVerbose: value=", value);
      if (value == 'on') {
        if (!isContentVerbose) {
	  isContentVerbose = true;
	  TAZAPI.setConfiguration("ContentVerbose", 'on');
	}
	return true;
      } else if (value == 'off') {
        if (isContentVerbose) {
	  isContentVerbose = false;
	  TAZAPI.setConfiguration("ContentVerbose", 'off');
	}
	return true;
      } else
	return false;
    }

    /**
     * setPosition
     *
     * setzt die Position
     *
     * @param string	neue Position oder 'EOF'
     *
     * @return bool	ok
     */
    function setPosition (value) {
      log("EPUBTAZ.setPosition: value=", value, " bookId=", bookId, " pageName=", pageName);
      var ret = false;
      position = value;
      if (bookId) {
        var url = pageName;
	if (position != 0) url += "?position=" + position;
	return setBookValue('currentPosition', url);
      } else
        return false;
    }

    /**
     * getPosition
     *
     * gibt die Position aus
     *
     * @return string	aktuelle Position
     */
    function getPosition () {
      return position;
    }

    /**
     * externLink
     * 
     * @param string url	Link
     */
    function externLink (url) {
      log("EPUBTAZ.externLink: ", url);
      TAZAPI.openUrl(url);
    }

    /**
     * internLink
     *
     * @param string url	Link
     */
    function internLink (url) {
      log("EPUBTAZ.internLink: ", url);
      TAZAPI.openUrl(url);
    }

    /**
     * pdfLink
     *
     * @param string url	Link
     */
    function pdfLink (url) {
      TAZAPI.openUrl(url);
    }

    /**
     * pdfLink
     *
     * @param string url	Link
     */
    function showDirectory (url) {
      log("EPUBTAZ.showDirectory:");
      if (render) {
	render();
      }
    }

    function checkBrowser () {
      isIos = /iPad|iPhone|iPod|Macintosh/.test(navigator.userAgent) && !window.MSStream;
    }

    /**
     * init
     *
     * Initalisiert das Objekt mit den Variablen aus dem Dokument
     */
    function init (/* render */) {
      checkBrowser();

      if ( typeof(pageParams) != 'undefined' ) {
	if ( typeof(pageParams.tazAppBookId    ) != 'undefined') bookId   = pageParams.tazAppBookId;
	if ( typeof(pageParams.tazAppIsDebug   ) != 'undefined') isDebug  = pageParams.tazAppIsDebug;
	if ( typeof(pageParams.tazAppIsDebugUrl) != 'undefined') debugUrl = pageParams.tazAppIsDebugUrl;
	if ( typeof(pageParams.tazAppIsEmpty   ) != 'undefined') isEmpty  = pageParams.tazAppIsEmpty;
      }
      if ( typeof(tazAppIsDebug)    != 'undefined') isDebug  = tazAppIsDebug;
      if ( typeof(tazAppIsDebugUrl) != 'undefined') debugUrl = tazAppIsDebugUrl;
      if (isDebug) TAZAPI.clearWebCache();
      log("EPUBTAZ.init: TAZAPI:", TAZAPI);

      if (isIos) isChangeArtikel = true;

      // Vor dem Rendern Konfigurations-Parameter setzten
      var g;
      var configTheme;
      referrer	= false;
      if ( (g = getBookValue('currentPosition')) ) referrer = g;
      if ( (g = myGetConfiguration("version"        )) && parseInt(g) != NaN) version = parseInt(g);
      if ( (g = myGetConfiguration("fontsize"       )) && parseInt(g) != NaN) fontsize = parseInt(g);
      if ( (g = myGetConfiguration("colsize"        )) && parseFloat(g) != NaN) colsize = parseFloat(g);
      if ( (g = myGetConfiguration("isScroll"       )) && g == 'on'  ) setIsScroll('on', true);
      if ( (g = getBookValue('isDebug'              )) && g == 'on'  ) isDebug          = true;
      if ( (g = getBookValue('viewMark'             )) && g == 'on'  ) viewMark         = true;
      if ( (g = myGetConfiguration("FullScreen"     )) && g == 'on'  ) isFullScreen     = true;
      if ( (g = myGetConfiguration("ContentVerbose" )) && g == 'off' ) isContentVerbose = false;
      if ( (g = myGetConfiguration("isScrollToNext" )) && g == 'off' ) isScrollToNext   = false;
      if ( (g = myGetConfiguration("isJustify"      )) && g == 'on'  ) isJustify        = true;
      if ( (g = myGetConfiguration("isPaging"       )) && g == 'off' ) isPaging         = false;
      if ( (g = myGetConfiguration("isNoPaging"     )) && g == 'on'  ) isPaging         = false;
      if ( (g = myGetConfiguration("isChangeArtikel")) && g == 'on'  ) isChangeArtikel  = true;
      if ( (configTheme = myGetConfiguration("theme")) ) setTheme(configTheme);

      // setIsScroll('on', true); Zum Testen von Safari

      if (isScroll) colsize = 1.0;

      setWindowFontsize();

      var savePosition = true;

      if (arguments.length > 0) {
        var arg = arguments[0];
        if (typeof(arg.render    ) != 'undefined') render = arg.render;
        if (typeof(arg.noPosition) != 'undefined' && arg.noPosition) savePosition = false;
      }

      pageName	= window.location.pathname.replace(/^.*[\/\\]/g, '');
      pageName	= pageName.replace(/\.landscape\./, '.');
      pageId	= pageName.replace(/\.html/, '');

      var sArg = window.location.search;
      var pArg = sArg.replace(/\?position=(\d+).*/, '$1');
      if (pArg != sArg) {
	position = parseInt(pArg);
      } else {
        pArg = sArg.replace(/\?position=(EOF).*/, '$1');
	if (pArg == 'EOF')
	  position = pArg;
      }
      if (window.devicePixelRatio && window.devicePixelRatio > 1) pixelRatio = window.devicePixelRatio;
      log("EPUBTAZ.init: bookId=", bookId, " pageName=", pageName, " position=", position,
        " isDebug=", isDebug, " isScroll=", isScroll, " render=", render!==false, " pixelRatio=", pixelRatio);

      TAZAPI.setConfiguration("bgColorNormal", bgColorNormal);
      TAZAPI.setConfiguration("bgColorSepia",  bgColorSepia);
      TAZAPI.setConfiguration("bgColorNight",  bgColorNight);
      if (savePosition) setPosition(position);

      var Platform =  myGetConfiguration("Platform");
      var Version  =  myGetConfiguration("Version");
      /* ###
      alert ("Platform=" + Platform + " Version=" + Version);
      */
    }

    /*
     * KLeine Hilfsfunktionen
     */

    function setElement (e, top, left, height, width) {
//      log("EPUBTAZ.setElement: id=", e.id, " top=", top, " left=", left, " height=", height, " width=", width);
      if (top    !== false) e.style.top    = top + 'px';
      if (left   !== false) e.style.left   = left + 'px';
      if (height !== false) e.style.height = height + 'px';
      if (width  !== false) e.style.width  = width + 'px';
      e.style.display = 'block';
    }

    function checkAndHide (/* elemente */) {
      for (var i = 0; i < arguments.length; i++) {
	if (!arguments[i])
	  return false;
	else
	  arguments[i].style.display = 'none';
      }
      return true;
    }

    function setGesture(params) {
      if (params.swipeUp   ) swipeUp    = params.swipeUp;
      if (params.swipeDown ) swipeDown  = params.swipeDown;
      if (params.swipeLeft ) swipeLeft  = params.swipeLeft;
      if (params.swipeRight) swipeRight = params.swipeRight;
      if (params.tap       ) tap        = params.tap;
    }

    function onGesture (name, x, y) {
      switch (name) {
	case "swipeLeft" : if (swipeLeft ) swipeLeft (); break;
	case "swipeRight": if (swipeRight) swipeRight(); break;
	case "swipeUp"   : if (swipeUp   ) swipeUp   (); break;
	case "swipeDown" : if (swipeDown ) swipeDown (); break;
	case "tap"       : if (tap       ) tap       (x,y, true); break; 
      }
    }

    function willHandleTap (x, y) {
      if (tap) {
        if (tap (x,y, false)) {
	  log("EPUBTAZ.willHandleTap: x=", x, " y=", y, " ret=true");
	  return "true";
	} else {
	  log("EPUBTAZ.willHandleTap: x=", x, " y=", y, " ret=false");
	  return "false";
	}
      }
      return "false";
    }

    return {
      // getters for computed properties
      get isFullScreen()	{ return isFullScreen; },
      get isContentVerbose()	{ return isContentVerbose; },
      get pixelRatio()		{ return pixelRatio; },
      get fontsize()		{ return screenFontsize(); },
      get bookmarks()		{ return bookmarks; },
      get bookId()		{ return bookId; },
      get pageName()		{ return pageName; },
      get viewMark()		{ return viewMark; },
      get referrer()		{ return referrer; },
      get colsize()		{ return colsize; },
      get isScroll()		{ return isScroll; },
      get isDebug()		{ return isDebug; },
      get isEmpty()		{ return isEmpty; },
      get lineHight()		{ return lineHight; },
      get isIos()		{ return isIos; },
      get isFoot()		{ return false; },
      get isSocial()		{ return false; },
      get isScrollToNext()	{ return isScrollToNext; },
      get isJustify()	        { return isJustify; },
      get isPaging()		{ return isPaging; },
      get isChangeArtikel()	{ return isChangeArtikel; },
      get position()		{ return position; },

      columnCount	: columnCount,
      log		: log,
      nextPage		: nextPage,
      prevPage		: prevPage,
      setViewMark	: setViewMark,
      showDirectory	: showDirectory,
      getDebug		: getDebug,
      setDebug		: setDebug,
      setFullScreen	: setFullScreen,
      setContentVerbose	: setContentVerbose,
      setScrollToNext	: setScrollToNext,
      setJustify	: setJustify,
      setNoPaging       : setNoPaging,
      setPaging		: setPaging,
      setFontsize	: setFontsize,
      incFontsize	: incFontsize,
      setColsize	: setColsize,
      incColsize	: incColsize,
      setTheme		: setTheme,
      setIsFoot		: setIsFoot,
      setIsSocial	: setIsSocial,
      setIsScroll	: setIsScroll,
      setPosition	: setPosition,
      getPosition	: getPosition,
      externLink	: externLink,
      internLink	: internLink,
      pdfLink		: pdfLink,
      setElement	: setElement,
      setBookValue	: setBookValue,
      getBookValue	: getBookValue,
      checkAndHide	: checkAndHide,
      setCallbackVal	: setCallbackVal,
      myGetValue	: myGetValue,
      myGetConfiguration: myGetConfiguration,
      setGesture	: setGesture,
      onGesture		: onGesture,
      willHandleTap	: willHandleTap,
      init		: init
    }
  } ());
}());
