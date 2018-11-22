// var tazAppIsDebug = true;
// var tazAppIsDebugUrl = 'http://10.10.3.1/ralf/tazAppLog.php?log=';
// var tazAppIsDebugUrl = 'http://dl.taz.de/ralf/tazAppLogT01.php?log=';

// -------------------------- Implementierung meiner Ableitung von TAZAPI ------------------------

try {
  "use strict";
  if ( TAZAPI === undefined) {

    var TAZAPI = (function() {
      var menuStatus	= false;
      var bookmarkJson	= false;

      return (function() {

        /**
	 * getBookmarks 
	 */
	function getBookmarks (callback, storageKey) {
	  if (!bookmarkJson) {
	    var bookmarkJson = EPUBTAZ.myGetValue(storageKey);
	  }
	  return bookmarkJson;
	}

        /**
	 * setBookmark 
	 */
	function setBookmark (name, status, storageKey, markList) {
	  TAZAPI.setValue(storageKey, JSON.stringify(markList));
	}

	/**
	 * pageReady
	 *
	 * Damit signalisiert das JavaScript, dass die Seite fertig gerendert
	 * und bereit zum Darstellen ist
	 */
	function pageReady (percent, pos, numberOfPages) {
	  console.log("pageReady: percent=" + percent + " pos=" + pos + " numberOfPages=" + numberOfPages);
	}

	/**
	 * startAnimation
	 *
	 * Übergangs-Animation starten in/out
	 *
	 * @param string	in_out		"in"|"out" für rein oder raus
	 * @param string	direction	"NS" | "SN" | "EW" | "WE" für von oben nach unten | unten nach oben 
	 *					| rechts nach links | links nach rechts
	 *
	 */ 
	function startAnimation (in_out, direction) {
	  EPUBTAZ.log("TAZAPI.startAnimation: in_out=", in_out, " direction=", direction);
	}

	/**
	 * openUrl
	 * 
	 * @param string url	Link
	 */
	function openUrl (url) {
	  EPUBTAZ.log("TAZAPI.openUrl: url=", url);
	  window.location.href = url;
	}

	// Konfiguration

	/**
	 * onConfigurationChanged
	 *
	 * JS Handler für Config-Änderungen in der APP
	 * Muss vom Javascript des ePubs zur Verfügung gestellt werden
	 *
	 * @param string	name	Name der Konfigurationsvariablen
	 * @param string	value	Neuer Wert der Konfigurationsvariablen
	 *
	 * @return bool	ok
	 *
	 */ 
	function onConfigurationChanged (name, value) {
	  throw 'abstrakte Methode onConfigurationChanged';
	}

	/**
	 * onShowDirectory
	 *
	 * JS Handler wenn das Inhalts-Verzeichnis aufgerufen wird
	 *
	 * @return bool	ok
	 *
	 */ 
	function onShowDirectory () {
	  throw 'abstrakte Methode onShowDirectory';
	}


	/**
	 * getConfiguration
	 *
	 * Konfigurationsvariablen
	 *
	 * @param string	name
	 * @param callback	callback Funktion
	 *
	 * @return string	value oder false, wenn es ihn nicht gibt
	 *			oder Arbeiten wir lieber mit Exeptions?
	 */
	function getConfiguration (name, callback) {
	  EPUBTAZ.log("TAZAPI.getConfiguration: name=", name);
	  var ret = localStorage.getItem('/config/'+name);
	  callback(ret);
	  if (ret)
	    return ret;
	  else
	    return null;
	}

	/**
	 * setConfiguration
	 *
	 * @param string	name	Name der Konfigurationsvariablen
	 * @param string	value	Neuer Wert der Konfigurationsvariablen
	 *
	 * return bool	ok
	 */
	function setConfiguration (name, value) {
	  EPUBTAZ.log("TAZAPI.setConfiguration: name=", name, " value=", value, " type=", typeof (value) );
	  if (value !== undefined) {
	    if (typeof (value) != 'string') value = value.toString();
	    return localStorage.setItem('/config/'+name, value);
	  }
	  return false;
	}

	// Values

	/**
	 * getValue
	 *
	 * Wert setzen
	 * Name/Werte-Paare wobei der Name ein Pfad ist, 
	 * der bei Daten zu einem ePub immer mit /bookId beginnt
	 *
	 * @param string	path
	 * @param callback	callback Funktion
	 *
	 * @return string	value oder false, wenn es ihn nicht gibt
	 *			oder Arbeiten wir dann mit Exeptions?
	 */
	function getValue(path, callback) {
	  EPUBTAZ.log("TAZAPI.getValue: path=", path);
	  var ret = localStorage.getItem(path);
	  callback(ret);
	  if (ret)
	    return ret;
	  else
	    return null;
	}

	/**
	 * setValue
	 *
	 * Wert setzen
	 *
	 * @param string	path
	 * @param string	value
	 *
	 * @return bool	ok
	 */
	function setValue (path, value) {
	  EPUBTAZ.log("TAZAPI.setValue: path=", path, " value=", value);
	  return localStorage.setItem(path, value);
	}

	/**
	 * removeValue
	 *
	 * Wert löschen
	 *
	 * @param path
	 *
	 * @return bool	ok
	 */
	function removeValue (path) {
	  EPUBTAZ.log("TAZAPI.removeValue: path=", path);
	  return removeItem(path);
	}

	/**
	 * removeValueDir
	 *
	 * Baumbereich löschen
	 *
	 * @param path
	 *
	 * @return bool	ok
	 */
	function removeValueDir (path) {
	  EPUBTAZ.log("TAZAPI.removeValueDir: path=", path);
	  return false;
	}

	/**
	 * listKeys
	 *
	 * Array mit allen Keys mit Value
	 *
	 * @param path
	 *
	 * @return array	oder false? bzw. Exeption
	 */
	function listKeys (path) {
	  EPUBTAZ.log("TAZAPI.listKeys: path=", path);
	  var ret;
	  for (var name in localStorage) { 
	    if (name.test(',^'+path+'/.+/'))
	      ret.name = localStorage[name];
	  }
	  return false;
	}

	// Vergessene Methoden

	/**
	 * clearWebCache
	 *
	 * Löscht den Cache von Webkit.
	 * gerade bei dem Debugging ist es gut den Cache zu löschen
	 *
	 */
	function clearWebCache () {
	  EPUBTAZ.log("TAZAPI.clearWebCache:");
	}

	/**
	 * netLog
	 *
	 * zum Debugging, am schicksten wäre es wenn im Hintergrund einfach die URL geöffnet wird
	 * Beim Test mache ich das jetzt mit einer Ajax-Funktion, so kann ich auf dem Server sehen
	 * was passiert. Es werden keine Daten zurück geliefert. Siehe setupApp.js
	 *
	 * @param string        url     URL
	 *
	 */
	function netLog (url) {
	  console.log(url);
	}

	function statechangeHandler () {	// macht nichts
	  return true;
	}

	/**
	 * getMenu
	 *
	 * Status vom Menü bzw. ActionBar
	 *
	 * @return bool	status     sichbar oder nicht sichtbar
	 *
	 */
	function getMenu () {
	  return menuStatus;
	}

	/**
	 * setMenu
	 *
	 * Status vom Menü bzw. ActionBar
	 *
	 * @param bool	status     sichbar oder nicht sichtbar
	 *
	 */
	function setMenu (status) {
	  menuStatus = status;
	  EPUBTAZ.log("TAZAPI.setMenu: menuStatus=", menuStatus);
	}

	function enableRegionScroll (flag) {
	}

	function beginRendering () {
	}

	function nextArticle () {
	  if (pageParams.nextPage) window.location.href = pageParams.nextPage;
	}

	function previousArticle () {
	  if (pageParams.prevPage) window.location.href = pageParams.prevPage;
	}

	function fifi (val) {
	  console.log(val);
	}

	return {
	  pageReady		: pageReady,
	  startAnimation	: startAnimation,
	  openUrl		: openUrl,
	  onConfigurationChanged: onConfigurationChanged,
	  getConfiguration	: getConfiguration,
	  setConfiguration	: setConfiguration,
	  getValue		: getValue,
	  setValue		: setValue,
	  removeValue		: removeValue,
	  removeValueDir	: removeValueDir,
	  listKeys		: listKeys,
	  clearWebCache		: clearWebCache,
	  netLog		: netLog,
	  getMenu		: getMenu,
	  setMenu		: setMenu,
	  getBookmarks		: getBookmarks,
	  setBookmark		: setBookmark,
	  enableRegionScroll	: enableRegionScroll,
	  beginRendering	: beginRendering,
	  nextArticle		: nextArticle,
	  previousArticle	: previousArticle,
	  fifi			: fifi,
	}
      } ());
    }());
  }
} catch (e) {
}

var oldKeyUpHandler = false;

  function keyCheck(event) {
    event.preventDefault();
    var code = event.keyCode;
    EPUBTAZ.log ("tazAppEvent.keyCheck: code=", code);
    switch (code) {
      case 37:	// Cursor Links
        TAZAPI.onGesture('swipeRight', 0, 0);
	break;
      case 39:	// Cursor Rechts
        TAZAPI.onGesture('swipeLeft', 0, 0);
	break;
      case 38:	//Cursor unten
        TAZAPI.onGesture('swipeDown', 0, 0);
	break;
      case 40:	// Cursor oben
        TAZAPI.onGesture('swipeUp', 0, 0);
	break;
      case 187:	// + auf Tastatur
      case 107:	// + auf Num-Tastatur
	EPUBTAZ.incFontsize(true);
	break;
      case 189:	// - auf Tastatur
      case 109:	// - auf Num-Tastatur
	EPUBTAZ.incFontsize(false);
	break;
      case 78:	// 'n'
	TAZAPI.onConfigurationChanged("theme", 'normal');
	break;
      case 83:	// 's'
	TAZAPI.onConfigurationChanged("theme", 'sepia');
	break;
      case 77:	// 'm'
	TAZAPI.onConfigurationChanged("theme", 'night');
	break;
      case 73:	// 'i'
	EPUBTAZ.internLink("content.xhtml");
	break;
      case 188:	// '<'
	EPUBTAZ.incColsize(false);
	break;
      case 190:	// '>'
	EPUBTAZ.incColsize(true);
	break;
      case 80:	// 'p'
        if (EPUBTAZ.getDebug())
	  EPUBTAZ.setDebug(false);
	else
	  EPUBTAZ.setDebug(true);
	break;
      case 86:	// 'v'
        if (EPUBTAZ.isFullScreen)
	  EPUBTAZ.setFullScreen('off');
	else
	  EPUBTAZ.setFullScreen('on');
	break;
      case 67:	// 'c'
        if (EPUBTAZ.isContentVerbose)
	  EPUBTAZ.setContentVerbose('off');
	else
	  EPUBTAZ.setContentVerbose('on');
	break;
      default:
        // if (oldKeyUpHandler) oldKeyUpHandler(event);
	break;
    }
    return false;
  }
  if (document.onkeyup) oldKeyUpHandler = document.onkeyup;
  document.onkeyup = keyCheck;
