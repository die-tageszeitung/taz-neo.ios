/**
 * setup
 *
 * Globale bekannte Objekte
 *	TAZAPI
 *	EPUBTAZ
 *	pageParams
 */
var setup = (function() {
  "use strict";

  return (function() {

    /**
     * init
     * Initalisiert das Objekt 
     */
    function init() {
      EPUBTAZ.log("setup.init:");
      tazAppEvent.init ();
    }

    // return public interface
    return {
      init		: init
    }
  } ());
}());

function setupWindow() {
  EPUBTAZ.init({});
  setup.init();
  TAZAPI.pageReady();
}
