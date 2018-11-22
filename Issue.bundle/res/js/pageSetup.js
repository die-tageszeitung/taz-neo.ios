/**
 * pageSetup
 *
 * Globale bekannte Objekte
 *	TAZAPI
 *	EPUBTAZ
 *	tazAppEvent
 *	columnPager
 */
var pageSetup = (function() {
  "use strict";
  var columnGap		= 0;
  var fontsize		= 0;
  var nCols		= 0;
  var sideMargin	= 28;
  var topMargin		= 6;
  var bottomMargin	= 0;
  var wWidth		= 0;
  var wHeight		= 0;
  var wasScroll		= false;
  var initPosition	= false;
  var wasScroll		= false;

  function pageReady () {
    regionPager.getPagePos();
    if (EPUBTAZ.isScroll) {
      EPUBTAZ.log("pageSetup.pageReady: scroll percentSeen=", scrollPager.percentSeen, " currentPos=", scrollPager.currentPos);
      TAZAPI.pageReady(scrollPager.percentSeen, scrollPager.currentPos, scrollPager.numberOfPages);
    } else {
      EPUBTAZ.log("pageSetup.pageReady: pager percentSeen=", regionPager.percentSeen, " currentPos=", regionPager.currentPos);

      TAZAPI.pageReady(regionPager.percentSeen, regionPager.currentPos, regionPager.numberOfPages);
    }
  }

  function nextArticle () {
    EPUBTAZ.log("pageSetup.nextArticle");
    TAZAPI.nextArticle(0);
    pageReady();
  }

  function previousArticle () {
    EPUBTAZ.log("pageSetup.previousArticle");
    TAZAPI.previousArticle(0);
    pageReady();
  }

  function scrollLeftTab () {
    EPUBTAZ.log("pageSetup.scrollLeftTab:");
    if (!scrollPager.leftTab()) {
      if (EPUBTAZ.isChangeArtikel) TAZAPI.previousArticle('EOF');	//  #### Bei Android Absturz
      pageReady();
    }
  }

  function scrollRightTab () {
    EPUBTAZ.log("pageSetup.scrollRightTab:");
    if (!scrollPager.rightTab()) {
      if (EPUBTAZ.isChangeArtikel) TAZAPI.nextArticle(0);	//  #### Bei Android Absturz
      pageReady();
    }
  }

  function scrollSwipeUp () {
    EPUBTAZ.log("pageSetup.scrollSwipeUp:");
    if (!scrollPager.pageUp()) {
      if (EPUBTAZ.isScrollToNext) TAZAPI.nextArticle(0);
    }
    pageReady();
  }

  function scrollSwipeDown () {
    EPUBTAZ.log("pageSetup.scrollSwipeDown:");
    if (!scrollPager.pageDown()) {
      if (EPUBTAZ.isScrollToNext) TAZAPI.previousArticle('EOF');
    }
    pageReady();
  }

  function regionJsSwipeLeft () {
    EPUBTAZ.log("pageSetup.regionSwipeLeft:");
    if (!regionPager.pageRight()) {
      if (EPUBTAZ.isScrollToNext) TAZAPI.nextArticle(0);
      pageReady();
    }
  }

  function regionJsSwipeRight () {
    EPUBTAZ.log("pageSetup.regionSwipeRight:");
    if (!regionPager.pageLeft()) {
      if (EPUBTAZ.isScrollToNext) TAZAPI.previousArticle('EOF');
      pageReady();
    }
  }

  function regionJsLeftTab () {
    EPUBTAZ.log("pageSetup.regionLeftTab:");
    if (!regionPager.leftTab()) {
      if (EPUBTAZ.isChangeArtikel) TAZAPI.previousArticle('EOF');	//  #### Bei Android Absturz
      pageReady();
    }
  }

  function regionJsRightTab () {
    EPUBTAZ.log("pageSetup.regionRightTab:");
    if (!regionPager.rightTab()) {
      if (EPUBTAZ.isChangeArtikel) TAZAPI.nextArticle(0);	//  #### Bei Android Absturz
      pageReady();
    }
  }

  // --------------------- Render ---------------------

  function setFontsize () {
    var newFontsize = EPUBTAZ.fontsize;
    if (newFontsize != fontsize) {
      fontsize = newFontsize;
      columnGap = fontsize;
    }
    return false;
  }

  function setupWidth() {
    EPUBTAZ.log("pageSetup.setupWidth: " );
    var ret = false;
    if (EPUBTAZ.isScroll) {
      if (sideMargin != fontsize) {
	sideMargin = fontsize;
	return true;
      }
    } else {
      var newNCols = EPUBTAZ.columnCount();
      var newMargin = columnGap;
      if (newMargin != sideMargin) {
	sideMargin = newMargin;
	ret = true;
      }
      if (newNCols != nCols) {
	nCols = newNCols;
	EPUBTAZ.log ("pageSetup.setupWidth: ColumnCount=", nCols);
	wWidth = window.innerWidth;
	return true;
      }
    }
    if (wWidth != window.innerWidth) {
      wWidth = window.innerWidth;
      return true;
    }
    return ret;
  }

  function setupHeight() {
    var fuss = document.getElementById('fuss');
    var ret = false;
    var newMargin = 6;
    if (!EPUBTAZ.isFullScreen) newMargin = columnGap;
    if (newMargin != topMargin) {
      topMargin = newMargin;
      ret = true;
    }
    if (fuss) {
      fuss.style.position = 'fixed';
      var newBottomMargin = 0;
      newBottomMargin = fuss.offsetHeight + 2;
      if (bottomMargin != newBottomMargin) {
	bottomMargin = newBottomMargin;
	EPUBTAZ.log("pageSetup.setupHeight: topMargin=", topMargin, " bottomMargin=", bottomMargin);
	return true;
      }
    }
    if (wHeight != window.innerHeight) {
      wHeight = window.innerHeight;
      return true;
    }
    return ret;
  }

  return (function() {
    function resetWindow() {
      EPUBTAZ.log("pageSetup.resetWindow:");
      
      var f=setFontsize();
      var w=setupWidth();
      var h=setupHeight();
      if (f || h || w) {
	var renderParams = {
	  nCols       : nCols,
	  columnGap   : columnGap,
	  fontsize    : fontsize,
	  leftMargin  : sideMargin,
	  rightMargin : sideMargin,
	  topMargin   : topMargin,
	  bottomMargin: bottomMargin,
	  wordPos     : 0
	};
	var lastPage = false;
	if (initPosition) {	// Nur beim ersten Mal - warum??
	  if (initPosition === 'EOF')
	    lastPage = true;
	  else
	    renderParams.wordPos = initPosition;
	  initPosition = false;
	}
	var currentPos = false;
	if (EPUBTAZ.isScroll) {
	  renderParams.wordPos = EPUBTAZ.getPosition();
	  scrollPager.render(renderParams);
	  currentPos = scrollPager.currentPos;
	  if (lastPage) scrollPager.lastPage();
	} else {
	  renderParams.wordPos = EPUBTAZ.getPosition();
	  regionPager.render(renderParams);
	  currentPos = regionPager.currentPos;
	  if (lastPage) regionPager.lastPage();
	}

	EPUBTAZ.log ("pageSetup.resetWindow: position=", currentPos, " ColumnCount=", nCols, " columnGap=", columnGap,
	  " sideMargin=", sideMargin, " topMargin=", topMargin, " bottomMargin=", bottomMargin, " isScroll=", EPUBTAZ.isScroll);
      }
    }

    /**
     * init
     *
     * Initalisiert das Objekt 
     */
    function init () {
      EPUBTAZ.log("pageSetup.init:");
      fontsize = EPUBTAZ.fontsize;
      columnGap = fontsize;

      if (EPUBTAZ.isScroll) {
        wasScroll = true;
        scrollPager.init ({
	  contentId	: 'content',
	  fotoId	: 'foto',
	});
	EPUBTAZ.setGesture ({
	  swipeUp	: scrollSwipeUp,
	  swipeDown	: scrollSwipeDown,
	  swipeLeft	: nextArticle,
	  swipeRight	: previousArticle,
	});
	tazAppEvent.init({
	  leftTab	: scrollLeftTab,
	  rightTab	: scrollRightTab,
	});
      } else {
        regionPager.init ({
	  contentId	: 'content',
	  titleId	: 'titel',
	  brotId	: 'brot',
	  fotoId	: 'foto',
	});
	EPUBTAZ.setGesture ({
	  swipeUp	: nextArticle,
	  swipeDown	: previousArticle,
	  swipeLeft	: regionJsSwipeLeft,
	  swipeRight	: regionJsSwipeRight,
	});
	tazAppEvent.init({
	  leftTab	: regionJsLeftTab,
	  rightTab	: regionJsRightTab,
	});
      }

      if ( window.onorientationchange )
	window.onorientationchange = pageSetup.resetWindow;
      else
	window.onresize = pageSetup.resetWindow;

      var pos = EPUBTAZ.getPosition();
      if (pos > 0 || pos === 'EOF') initPosition = pos;
    }

    // return public interface
    return {
      resetWindow	: resetWindow,
      pageReady		: pageReady,
      init		: init
    }
  } ());
}());

// function setupWindow() {
 function newSetupWindow() {
  // $(document).unbind();
  EPUBTAZ.init( {render:pageSetup.resetWindow} );
  EPUBTAZ.bookmarks.setupMarks();
  pageSetup.init();
  pageSetup.resetWindow();
}
function setupWindow() {
// function newSetupWindow() {
}

$(window).one("load", newSetupWindow);

