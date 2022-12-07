

// -------------------------- sectionSetup ------------------------

/**
 * Globaler Handler für die Section
 */

var sectionSetup = (function() {
  "use strict";
  var isDebug		= true;

  return (function() {

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
	console.log(str);
      }
    }

    /**
     * init
     *
     */
    function init () {
      /*
      if (typeof tazApi.getBookmark !== "undefined") {
	log("Wir haben Bookmarks");
      } else {
	log("Wir haben keine Bookmarks");
      }
      */
    }

    return {
      // getters for computed properties
      get isDebug()	{ return isDebug; },

      log		: log,
      init		: init
    }
  } ());
}());

function newSectionWindow() {
  sectionSetup.init();
}

// window.addEventListener('load', newSectionWindow);

/*
 *  Functions to support bookmarks, i.e. display and toggeling of bookmark
 *  icons.
 */

/* Set bookmark icon */
function setBookmark(artName, hasBookmark) {
  let b = document.getElementById(artName);
  if (b) {
    if (hasBookmark) {
      b.src = "resources/StarFilled.svg";
    }
    else {
      b.src = "resources/Star.svg";
    }
    b.style.display = "block";
  }
}

/* Return basename of path (ie. without leading directory) */
function basename(path) {
  return path.substr(path.lastIndexOf("/")+1);
}

/* Is called as click function to toogle bookmark */
function toggleBookmark(button) {
  let wasBookmark = basename(button.src) == "StarFilled.svg";
  tazApi.setBookmark(button.id, !wasBookmark, true);
}

/* Set up click functions for bookmark icons */
function setupButtons() {
  for (let b of document.getElementsByClassName("bookmarkStar")) {
    b.addEventListener("click", (event) => {
      event.preventDefault();
      toggleBookmark(event.target);
    });
  }
}

/* Being called by native side when bookmarks change */
tazApi.onBookmarkChange = function (artName, hasBookmark) {
  setBookmark(artName, hasBookmark);
};

/* Is called by tazApi.getBookmarks */
function setupBookmarks(arts) {
  if (arts) {
    for (let a of arts) {
      setBookmark(a, true);
    }
  }
  for (let b of document.getElementsByClassName("bookmarkStar")) {
    if (!b.style.display || b.style.display == "none") {
      setBookmark(b.id, false);
    }
  }
}

/* 
 * Initialize bookmark buttons when DOM is ready and tazApi.getBookmarks
 * is defined.
 */ 
document.addEventListener("DOMContentLoaded", (e) => {
  if (typeof tazApi.getBookmarks === "function") {
    setupButtons();
    tazApi.getBookmarks(setupBookmarks);
  }
});
