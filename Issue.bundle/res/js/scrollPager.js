/**
 * scrollPager
 *
 * Globale bekannte Objekte
 *	TAZAPI
 *	EPUBTAZ
 */
var scrollPager = (function() {
  "use strict";
  var content		= false;
  var foto		= false;
  var markWord		= false;
  var viewWidth		= false;
  var viewHeight	= false;
  var percentSeen	= 0;
  var currentPos	= 0;
  var leftMargin	= false;
  var rightMargin	= false;
  var topMargin		= false;
  var bottomMargin	= false;
  var wasScroll		= false;
  var timer		= false;
  var numberOfPages	= 0;

  function lastPage () {
    EPUBTAZ.log ("scrollPager.lastPage:");
    content.scrollTop = content.scrollHeight - viewHeight;
  }

  function pageDown (params) {
    var ret = true;
    if (content.scrollTop <= 0)
      ret = false;
    // getPagePos();
    return ret;
  }

  function pageUp (params) {
    var ret = true;
    if (content.scrollHeight - content.scrollTop <= viewHeight)
      ret = false;

    // getPagePos();
    return ret;
  }

  function getPagePos () {
    percentSeen = Math.round((content.scrollTop + viewHeight) * 100 / (content.scrollHeight));
    currentPos  = Math.round(content.scrollTop * 1000000 / (content.scrollHeight ));
    EPUBTAZ.log ("scrollPager.getPagePos: percentSeen=", percentSeen, " currentPos=", currentPos);
    EPUBTAZ.setPosition(currentPos);
  }

  function setPagePos(wordPos) {
    EPUBTAZ.log ("scrollPager.setPagePos wordPos=", wordPos);
    if (wordPos) {
      if (wordPos == 'EOF') {
        lastPage();
      } else if ( wordPos > 0) {
        var pos = Math.round((content.scrollHeight) * wordPos / 1000000);
        if (pos < 0) pos = 0;
	content.scrollTop = pos;
	EPUBTAZ.log ("scrollPager.setWordPos wordPos=", wordPos, " pos=", pos);
	getPagePos();
      }
    }
  }

  function scrollHandler () {
    var waitScroll = function() {
      getPagePos();
      TAZAPI.pageReady(percentSeen, currentPos, numberOfPages);
      if (timer) clearTimeout(timer);
      timer = false;
    }
    if (timer) clearTimeout(timer);
    timer = setTimeout(waitScroll, 500);
  }

  function leftTab () {
    if (content.scrollTop > 0) {
      var y = content.scrollTop - (viewHeight - topMargin);
      if (y < 0) y = 0;
      // content.scrollTop = y;
      $(content).animate({ scrollTop: y}, 300);
      return true;
    }
    return false;
  }

  function rightTab () {
    if (content.scrollHeight - content.scrollTop > viewHeight) {
      var m = content.scrollHeight - viewHeight;
      var y = content.scrollTop + (viewHeight - topMargin);
      if (y > m) y = m;
      // content.scrollTop = y;
      $(content).animate({ scrollTop: y}, 300);
      return true;
    }
    return false;
  }

  function preCheckContent (node) {
    if (node.style && node.style.display == 'none') {
      console.log("Lösche "+ node.className);
      node.parentNode.removeChild(node);
    } else {
      var marginRight = '1em';
      var marginLeft  = '0em';
      var isFloat     = true;
      if (node.classList && (node.classList.contains('MediaImg') || node.classList.contains('AutorImg'))) {
        var isAutor = node.parentNode.className == 'AutorA';
        var isBio   = node.classList.contains('ImgBio') && !isAutor;
        var iw = node.naturalWidth;
	if (isBio) {
	  marginRight = '0em';
	  marginLeft  = '1em';
	}

        if (node.naturalWidth > (viewWidth * 2 / 3)) {
	  iw = viewWidth;
	  if (isBio)
	    marginRight = '0em';
	  else
	    marginLeft = '0em';
	} else {
	  if (node.naturalWidth > viewWidth/2) iw = viewWidth / 2;
	  if (node.className.search(/Maske/) != -1) {
	    if (isBio)
	      marginLeft = '0.5em';
	    else
	      marginRight = '0.5em';
	    node.style.webkitShapeMargin = '0.5em';
	  } else {
	    if (isBio) {
	      marginLeft = '1em';
	      iw = viewWidth / 3;
	    } else {
	      marginRight = '1em';
	      if (isAutor) iw = viewWidth / 3;
	    }
	  }
	  node.style.marginTop = '0.2em';
	}
	node.style.marginRight = marginRight;
	node.style.marginLeft  = marginLeft;
	node.style.width = iw + 'px';

	if (iw > viewWidth - EPUBTAZ.lineHight * 6) {
	  isFloat = false;
	}

	if (node.nextSibling && node.nextSibling.className && node.nextSibling.className.search(/MediaButze/) != -1) {
	  var n = node.nextSibling;
	  n.style.marginRight = marginRight;
	  if (!isFloat) {
	    n.style.width = viewWidth + 'px';
	    n.className += ' ImgFullsize';
	  } else {
	    n.style.width = iw + 'px';
	  }
	  if (n.nextElementSibling && n.nextElementSibling.nodeName == 'P')
	    n.nextElementSibling.style.textIndent = '0em';
	  n.style.marginRight = marginRight;
	} else {
	  if (node.nextElementSibling && node.nextElementSibling.nodeName == 'P')
	    node.nextElementSibling.style.textIndent = '0em';
	}
      } else if (node.classList && (node.classList.contains('EinzelFoto') )) {
        node.parentNode.removeChild(node);
      } else if (node.hasChildNodes()) {
        for (var i=node.childNodes.length-1; i >= 0; i--)
          preCheckContent(node.childNodes[i]);
      }
    }
  }


  function render (params) {
    leftMargin		= params.leftMargin;
    rightMargin		= params.rightMargin;
    topMargin		= params.topMargin;
    bottomMargin	= params.bottomMargin;

    if (EPUBTAZ.isScroll && !EPUBTAZ.isEmpty) {
	EPUBTAZ.log ("scrollPager.render: leftMargin=", leftMargin, " rightMargin=", rightMargin, 
	  " topMargin=", topMargin, " bottomMargin=", bottomMargin);
      wasScroll = true;
      if (content) {
        viewHeight = window.innerHeight - topMargin - bottomMargin;
	viewWidth  = window.innerWidth - leftMargin - rightMargin;

	if (viewWidth / EPUBTAZ.lineHight > 25) {
	  viewWidth = EPUBTAZ.lineHight * 25;
	  leftMargin = rightMargin = (window.innerWidth - viewWidth) / 2;
	}

	content.style.display = 'none';
	content.style.position = 'absolute';
	content.style.top = 0 + 'px';
	content.style.width = viewWidth + 'px';
	content.style.height = viewHeight + 'px';
	content.style.left = 0 + 'px';
	content.style.right = 0 + 'px';
	content.style.paddingLeft = leftMargin + 'px';
	content.style.paddingRight = rightMargin - 2 + 'px';

	content.style.overflow  = 'auto';
	content.style.overflowY = 'auto';
	content.style.overflowX = 'hidden';
	
	content.style.display = 'block';
	preCheckContent(content);

	setPagePos(params.wordPos);
	numberOfPages = Math.ceil(content.scrollHeight / viewHeight);
	getPagePos();
	EPUBTAZ.log("scrollPager:initRegion: height=", viewHeight, " viewWidth=", viewWidth);
      }
      pageSetup.pageReady();
    }
  }

  return (function() {

    /**
     * init
     *
     * Initalisiert das Objekt 
     */
    function init (params) {
      EPUBTAZ.log("scrollPager.init: contentId=", params.contentId);
      TAZAPI.enableRegionScroll(true);
      content = document.getElementById(params.contentId);
//      content.addEventListener("scroll", scrollPager.scrollHandler, false);
      if ( (foto = document.getElementById(params.fotoId)) ) foto.style.display = 'block';
      content.onscroll = scrollPager.scrollHandler;
      if (content && EPUBTAZ.isJustify) content.classList.add('isJustify');
    }

    // return public interface
    return {
      get percentSeen()		{ return percentSeen; },
      get currentPos()		{ return currentPos; },
      get numberOfPages()	{ return numberOfPages; },

      scrollHandler	: scrollHandler,
      pageUp		: pageUp,
      pageDown		: pageDown,
      lastPage		: lastPage,
      leftTab		: leftTab,
      rightTab		: rightTab,
      render		: render,
      init		: init
    }
  } ());
}());
