/**
 * verzeichnisSetup
 *
 * Globale bekannte Objekte
 *	TAZAPI
 *	EPUBTAZ
 */

function newSetupWindow() {
  EPUBTAZ.init();
}

$(window).one("load", newSetupWindow);

