/**
 * regionPager
 *
 * Globale bekannte Objekte
 *	TAZAPI
 *	EPUBTAZ
 */

var regionPager = (function() {
  "use strict";
  var titel		= false;
  var brot		= false;
  var content		= false;
  var foto		= false;
  var viewWidth		= false;
  var viewHeight	= false;
  var numberOfPages	= 0;
  var percentSeen	= 0;
  var columnGap		= false;
  var colWidth		= 0;
  var nCols		= false;
  var fontsize		= false;
  var leftMargin	= false;
  var rightMargin	= false;
  var topMargin		= false;
  var bottomMargin	= false;
  var timer		= false;
  var page		= 0;
  var pagesPos		= false;
  var lastGap		= false;
  var nextBrot		= false;
  var isRender		= false;
  var regionsBrot	= false;
  var currentPos	= false;
  var bilderListe	= false;

  var workWidth		= 0;
  var colHeight		= 0;
  var left		= 0;

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

  function lastPage () {
    EPUBTAZ.log ("regionPager.lastPage:");
    window.scrollTo(pagesPos[pagesPos.length-1], 0);
  }

  function pageLeft () {
    var ret = true;
    if (window.pageXOffset <= 0)
      ret = false;
    EPUBTAZ.log ("regionPager.pageLeft: ", ret, " pageXOffset=", window.pageXOffset);
    return ret;
  }

  function pageRight () {
    var ret = true;
    if (viewWidth + leftMargin <= window.pageXOffset + window.innerWidth)
      ret = false;

    EPUBTAZ.log ("regionPager.pageLeft: ", ret, " pageXOffset=", window.pageXOffset, " windowWidth=", window.innerWidth, 
      " viewWidth=", viewWidth);
    return ret;
  }

  function getPagePos () {
    for(page=0; page<pagesPos.length; page++) {
      if (page >= pagesPos.length -1 || window.pageXOffset >= pagesPos[page] && window.pageXOffset < pagesPos[page+1]) 
        break;
    }
    percentSeen = Math.round(((window.pageXOffset + (window.innerWidth )) * 100 / (leftMargin + viewWidth)));
    currentPos  = Math.round(window.pageXOffset * 1000000 / (leftMargin + viewWidth));
    EPUBTAZ.log ("regionPager.getPagePos: percentSeen=", percentSeen, " numberOfPages=", numberOfPages, " currentPage=", page);
    EPUBTAZ.setPosition(currentPos);
  }

  function setPagePos (wordPos) {
    EPUBTAZ.log ("regionPager.setPagePos wordPos=", wordPos);
    if (wordPos) {
      if (wordPos == 'EOF') {
        lastPage();
      } else if ( wordPos > 0) {
        var pos = Math.round((viewWidth + leftMargin) * wordPos / 1000000);
        if (pos <= 0) {
	  if (window.pageXOffset > 0) window.scrollTo(0, 0);
	} {
	  window.scrollTo(pos, 0);
	}
	EPUBTAZ.log ("regionPager.setWordPos wordPos=", wordPos, " pos=", pos);
	getPagePos();
      }
    }
  }

  function leftTab () {
    EPUBTAZ.log ("regionPager.leftTab");
    if (pagesPos && window.pageXOffset > 0) {
      var i = pagesPos.length - 1;
      while (i > 0 && (window.pageXOffset <= pagesPos[i])) i--;
      if (i >= 0) {
	// window.scrollTo(pagesPos[i], 0);
         $('html, body').animate({ scrollLeft: (pagesPos[i])}, 300);
	return true;
      }
    }
    return false;
  }

  function rightTab () {
    EPUBTAZ.log ("regionPager.rightTab");
    if (pagesPos) {
      var i = 0;
      while (i < pagesPos.length && pagesPos[i] <= window.pageXOffset) i++;
      if (i < pagesPos.length) {
         $('html, body').animate({ scrollLeft: (pagesPos[i])}, 300);
	// window.scrollTo(pagesPos[i], 0);
	return true;
      }
    }
    return false;
  }

  function preCheckContent (node, width) {
    if (node.style && node.style.display == 'none') {
      // console.log("Lösche "+ node.className);
      node.parentNode.removeChild(node);
    } else {
      var marginRight = '1em';
      var marginLeft  = '0em';
      var isFloat     = true;
      if (node.classList && (node.classList.contains('MediaImg') || node.classList.contains('AutorImg'))) {
	var isAutor    = node.parentNode.classList.contains('AutorA');
	var isBio      = node.classList.contains('ImgBio') && !isAutor;
	var isMain     = node.parentNode.id == 'foto';
	if (isAutor || isBio ) { // Erstmal nur Hauptbild, Autoren und Bios
	  var iw = node.naturalWidth;
	  if (isBio) {
	    marginRight = '0em';
	    marginLeft  = '1em';
	  }

	  if (!isBio && !isAutor && node.naturalWidth > (colWidth * 2 / 3)) {
	    iw = colWidth;
	    if (isBio)
	      marginRight = '0em';
	    else
	      marginLeft = '0em';
	  } else {
	    if (node.naturalWidth > colWidth/2) iw = colWidth / 2;
	    if (node.className.search(/Maske/) != -1) {
	      if (isBio)
		marginLeft = '0.5em';
	      else
		marginRight = '0.5em';
	      node.style.webkitShapeMargin = '0.5em';
	    } else {
	      if (isBio) {
		marginLeft = '1em';
		iw = colWidth / 3;
	      } else {
		marginRight = '1em';
		if (isAutor) iw = colWidth / 3;
	      }
	    }
	    node.style.marginTop = '0.2em';
	  }
	  node.style.marginRight = marginRight;
	  node.style.marginLeft  = marginLeft;
	  node.style.width = iw + 'px';

	  if (iw > colWidth - EPUBTAZ.lineHight * 6) {
	    isFloat = false;
	  }

	  if (node.nextSibling && node.nextSibling.className && node.nextSibling.className.search(/MediaButze/) != -1) {
	    var n = node.nextSibling;
	    n.style.marginRight = marginRight;
	    if (!isFloat) {
	      n.style.width = colWidth + 'px';
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
	} else {
	  if (node.nextSibling && node.nextSibling.className && node.nextSibling.className.search(/MediaButze/) != -1) {
	    node.nextSibling.parentNode.removeChild(node.nextSibling);
	  }
	  node.parentNode.removeChild(node);
	}
      } else if (node.classList && (node.classList.contains('EinzelFoto') || node.id == 'foto')) {
	if (!bilderListe) bilderListe = new Array;
	bilderListe.push(node);
      } else if (node.hasChildNodes()) {
	for (var i=node.childNodes.length - 1; i >= 0; i--)
	  preCheckContent(node.childNodes[i], width);
      }
    }
  }

  function getImg(node) {
    if (node.nodeName == 'IMG') {
      return node;
    }
    if (node.hasChildNodes()) {
      for (var i=0; i < node.childNodes.length; i++) {
	var nw = getImg(node.childNodes[i]);
	if (nw) return nw;
      }
    }
  }

  function checkFlowBrot (flowBrot, element, fbp) {
    if (element.nodeType == 1) {
      var elementPosition = $(element).offset();
      var elementWidth    = $(element).width();
      var elementRight    = elementPosition.left + elementWidth;

      if ( elementRight > fbp.right ) return false;

      if (element.classList.contains('Initial') || (element.nodeName == 'DIV' && EPUBTAZ.isIos)) {
	var elementHeight   = $(element).height();
	var elementUpper    = elementPosition.top + elementHeight + EPUBTAZ.lineHight * 5;

	if ( elementUpper > fbp.upper ) {
	  if (fbp.right - (elementRight + colWidth + columnGap) > 0) {
	    if (fbp.height > elementHeight + EPUBTAZ.lineHight * 5) return true;
	  }
	  return false;
	}
      }
    }
    return true;
  }

  function addBrotElement (flowBrot, element, root, fbp) {
    root.appendChild (element);
    if ( checkFlowBrot(flowBrot, element, fbp) )
      return true;
    else {
      root.removeChild(element);
      return false;
    }
  }

  function addBrotWord (flowBrot, element, np, fbp) {
    np.appendChild (element);
    if ( checkFlowBrot(flowBrot, element, fbp) )
      return true;
    else {
      np.removeChild(element);

      if (EPUBTAZ.isJustify && !EPUBTAZ.isEmpty) {
	if (typeof np.style.textAlignLast === "undefined") { // Safari
	  var fil = ' ';
	  var len = 0;
	  while (len <= 2*colWidth) {
	    len += EPUBTAZ.lineHight;
	    fil += '_';
	  }
	  fil += ' ';
	  np.appendChild(document.createTextNode(fil));
	} else {
	  if (np.nodeName == 'P')
	    np.style.textAlignLast = 'justify';
	  else if (np.parentElement && np.parentElement.nodeName == 'P')
	    np.parentElement.style.textAlignLast = 'justify';
	}
      }

      return false;
    }
  }

  function addPar(flowBrot, par, np, fbp) {
    var fit = false;
    var delWordList = new Array();
    var delSpanList = new Array();
    for (var j=0; j < par.childNodes.length; j++) {
      var node = par.childNodes[j];
      if ((node.nodeType == 1 || node.nodeType == 3) && !node.childElementCount) {
	if ( (fit = addBrotWord(flowBrot, node.cloneNode(true), np, fbp)) )
	  delWordList.push(node);
	else
	  break;
      } else {
	var node = par.childNodes[j];
	var sElement = node.cloneNode(false);
	if ( (fit = addBrotElement(flowBrot, sElement, np, fbp)) ) {
	  fit = addPar(flowBrot, node, sElement, fbp);
	}
	if (fit)
	  delSpanList.push(node);
	else
	  break;
      }
    }
    if (delWordList.length) {
      for (var n = delWordList.length-1; n >= 0; n--) {
	var wp = delWordList[n];
	if (wp.parentNode) wp.parentNode.removeChild(wp);
      }
    }
    if (delSpanList.length) {
      for (var n = delSpanList.length-1; n >= 0; n--) {
	var wp = delSpanList[n];
	if (wp.parentNode) wp.parentNode.removeChild(wp);
      }
    }
    return fit;
  }

  function addFlowBrot (top, height, cols) {
    // console.log("addFlowBrot: top=" + top);
    var bw = cols * colWidth;
    if (cols > 1) bw += columnGap * (cols - 1);
    if (brot && brot.hasChildNodes()) {
      var flowBrot = document.createElement("div");
      flowBrot.style.position		= 'absolute';
      flowBrot.style.top		= top + 'px';
      flowBrot.style.left		= left + 'px';
      flowBrot.style.width		= bw + 'px';
      flowBrot.style.height		= height + 'px';
      flowBrot.style.webkitColumnCount	= cols;
      flowBrot.style.columnCount	= cols;
      flowBrot.style.webkitColumnFill	= 'auto';
      flowBrot.style.columnFill		= 'auto';
      flowBrot.style.webkitColumnGap	= columnGap + 'px';
      flowBrot.style.columnGap		= columnGap + 'px';
      flowBrot.style.webkitColumnWidth	= colWidth + 'px';
      flowBrot.style.columnWidth	= colWidth + 'px';
      flowBrot.style.overflow		= 'hidden';
      content.insertBefore(flowBrot, brot);
      var fit = true;
      var flowBrotPosition = $(flowBrot).offset();
      var flowBrotWidth    = $(flowBrot).width();
      var flowBrotHeight   = $(flowBrot).height();
      var fbp = {
        top    : flowBrotPosition.top,
        left   : flowBrotPosition.left,
        width  : flowBrotWidth,
        height : flowBrotHeight,
	right  : flowBrotPosition.left + flowBrotWidth + 0.5 * columnGap,
	upper  : flowBrotPosition.top + flowBrotHeight,
      };
      while(fit) {
	var delNodeList = new Array();
	for (var i=0; i < brot.childNodes.length; i++) {
	  var node = brot.childNodes[i];
	  if (node.nodeName == 'P' && node.className != 'Zwischentitel') {
	    var np = node.cloneNode(false);
	    if ( (fit = addBrotElement(flowBrot, np, flowBrot, fbp)) ) {
	      if (!(fit = addPar(flowBrot, node, np, fbp)) ) {
		node.className = 'oeinz';	// Kein Initial und Einzug
		break;
	      }
	    } else
	      break;
	  } else {
	    fit = addBrotElement(flowBrot, node.cloneNode(true), flowBrot, fbp);
	  }
	  if (fit) delNodeList.push(node);
	}
	if (delNodeList.length) {
	  for (var n = delNodeList.length-1; n >= 0; n--) {
	    var sp = delNodeList[n];
	    sp.parentNode.removeChild(sp);
	  }
	}
	fit = false;
      }
    }
    left += bw + columnGap;
  }

  function renderRegion(colTop) {
    var img        = 0;
    var imgWidth   = 0;
    var titelTop   = colTop;
    var iCol       = 0;
    var regionBrot = false;
    var regionId   = 0;
    if (brot) brot.style.display = 'none';
    if (bilderListe) {
      bilderListe.reverse();
      var isFit = false;
      for (var bi=0; bi<bilderListe.length; bi++) {
	var bild    = bilderListe[bi];
	var picCols = 0;
	bild.id     = 'bild'+bi;
	if ( (img = getImg(bild)) ) {

	  var w = 0;
	  imgWidth = img.naturalWidth;

	  while (w <= imgWidth) {
	    w += colWidth + columnGap;
	    picCols++;
	  }
	  w -= columnGap;
	  if (w <= colWidth) {
	    if (imgWidth < colWidth / 2)
	      imgWidth = colWidth / 2;
	    else
	      imgWidth = w;
	  } else if (w - colWidth / 2 > imgWidth) {
	    imgWidth = w - colWidth - columnGap;
	    picCols--;
	  } else
	    imgWidth = w;
	  

	  isFit = false;
	  while (!isFit && picCols > 0) {

	    img.width = imgWidth;
	    if (imgWidth < colWidth)
	      bild.style.width        = colWidth + 'px';
	    else
	      bild.style.width        = imgWidth + 'px';

	    bild.style.position     = 'absolute';
	    bild.style.top          = titelTop + 'px';
	    bild.style.left         = left + 'px';
	    bild.style.marginBottom = '0em';
	    bild.style.height       = 'auto';
	    if (EPUBTAZ.isDebug) bild.style.background = '#AAEE44';

	    var bildHeight   = $(bild).height();

	    // colTop = titelTop + bild.offsetHeight + EPUBTAZ.lineHight;
	    colTop = titelTop + bildHeight + EPUBTAZ.lineHight;

	    var offset = Math.round(titelTop % EPUBTAZ.lineHight);
	    if (offset != 0) offset = Math.round(EPUBTAZ.lineHight) - offset;
	    colTop = colTop + offset;

	    colHeight = viewHeight - colTop;
	    if (colHeight < (0 - EPUBTAZ.lineHight)) {
	      if (picCols == 1) {
	        if (imgWidth < colWidth)
		  picCols = 0;
		else
		  imgWidth = colWidth / 2;
	      } else {
		picCols--;
		imgWidth = w - colWidth - columnGap;
	      }
	    } else
	      isFit = true;
	  }
	}
	if (imgWidth < colWidth) imgWidth = colWidth;

	iCol=0;

	if (!isFit) {
	  if (bi == 0)
	    bilderListe.unshift(bild);
	  else
	    bild.style.display = 'none';
	  picCols = 0;
	  colTop = titelTop;
	  colHeight = viewHeight - titelTop;
	} else if (colHeight < EPUBTAZ.lineHight * 2) {
	  if (imgWidth <= workWidth) {
	    colTop = titelTop;
	    colHeight = viewHeight - titelTop;
	    iCol = picCols;
	    left += imgWidth + columnGap;
	  } else {
	    picCols = 0;
	    bild.style.display = 'none';
	    colTop = titelTop;
	    colHeight = viewHeight - titelTop;
	  }
	}
	// console.log("Bild iCol=" + iCol + " nCols=" + nCols + " colTop=" + colTop + " picCols=" + picCols + " left=" +left);
	if (brot && brot.hasChildNodes()) {
	  if (iCol == 0 && picCols)
	    addFlowBrot (colTop, colHeight, picCols);
	  if (picCols < nCols) {
	    colHeight = viewHeight - titelTop;
	    addFlowBrot (titelTop, colHeight, nCols - picCols);
	  }
	} else
	  left += picCols * (colWidth + columnGap);
	colTop = titelTop = 0;
      }
    } else if (brot && brot.hasChildNodes()) {	// Keine Bilder
      addFlowBrot (colTop, colHeight, nCols);
    }

    colTop = 0;
    colHeight = viewHeight;
    if (brot && brot.hasChildNodes()) {
      brot.style.position		= 'absolute';
      brot.style.top			= '0px';
      brot.style.left			= left + 'px';
      brot.style.height			= colHeight + 'px';
      brot.style.webkitColumnFill	= 'auto';
      brot.style.columnFill		= 'auto';
      brot.style.webkitColumnGap	= columnGap + 'px';
      brot.style.columnGap		= columnGap + 'px';
      brot.style.webkitColumnWidth	= colWidth + 'px';
      brot.style.columnWidth		= colWidth + 'px';
      brot.style.width			= colWidth + 'px';
      brot.style.display		= 'block';
    }
    renderRest();
  }

  function renderRest() {
    viewWidth = content.scrollWidth;
    if (content.scrollWidth > workWidth + columnGap)
      viewWidth += columnGap;
    content.style.width = viewWidth + 'px';
    pagesPos = new Array(0);
    var np = 0;
    var pageWidth = workWidth + 2 * columnGap;
    while (np < viewWidth) {
      pagesPos.push(np);
      np += pageWidth - columnGap;
    }
    /* letzte Seite ermitteln */
    if (pagesPos.length > 1 && (pagesPos[pagesPos.length-1] + pageWidth) > viewWidth) {
      pagesPos[pagesPos.length-1] = viewWidth - (workWidth + columnGap);
    }

    numberOfPages = pagesPos.length;

    EPUBTAZ.log("regionPager:initRegion: height=", viewHeight, " left=", left, " colWidth=", colWidth, " nCols=", nCols,
    " viewWidth=", viewWidth, " workWidth=", workWidth, " numberOfPages=", numberOfPages);
    isRender = true;
  }

  function clearRegion(regions) {
    if (regions) {
      for (var i=regions.length-1; i>=0; i--)
        content.removeChild(regions[i]);
    }
  }


  function render (params) {
    if (isRender) {
      TAZAPI.openUrl(EPUBTAZ.pageName + "?EPUBTAZ.position=" + EPUBTAZ.position);
      // console.log("regionPager.render: nach reload, nur einmal rendern");
      return;
    }
    columnGap		= params.columnGap;
    nCols		= params.nCols;
    fontsize		= params.fontsize;
    leftMargin		= params.leftMargin;
    rightMargin		= params.rightMargin;
    topMargin		= params.topMargin;
    bottomMargin	= params.bottomMargin;
    if (content) {
      EPUBTAZ.log ("regionPager.render: ColumnCount=", nCols, " columnGap=", columnGap,
	" leftMargin=", leftMargin, " rightMargin=", rightMargin, " topMargin=", topMargin, " bottomMargin=", bottomMargin);

      clearRegion(regionsBrot );
      regionsBrot  = new Array();

      content.style.position = 'absolute';
      content.style.top = topMargin + 'px';
      content.style.left = leftMargin + 'px';

      workWidth = window.innerWidth - (leftMargin + rightMargin);
      // content.style.width = workWidth + 'px';
      viewHeight = Math.floor(window.innerHeight - topMargin - bottomMargin);
      content.style.height = viewHeight + 'px';

      // Kein Titel fehlt!!!

      if (titel) {
	titel.style.position = 'absolute';
	titel.style.width = workWidth + 'px';
	titel.style.top = 0;
	titel.style.left = left + 'px';
	titel.style.height = viewHeight + 'px';
	if (EPUBTAZ.isDebug) titel.style.background = '#DDFFDD';
	left += workWidth + columnGap;

      }
      left -= workWidth + columnGap;
      titel.style.height = 'auto';

      colWidth = workWidth;
      var colTop = 0;

      if (titel && (titel.scrollHeight + 2*EPUBTAZ.lineHight) > viewHeight) {
        titel.style.webkitColumnCount = 1;
        titel.style.columnCount = 1;
        titel.style.webkitColumnFill = 'auto';
        titel.style.columnFill = 'auto';
        titel.style.webkitColumnGap = columnGap + 'px';
        titel.style.columnGap = columnGap + 'px';
        titel.style.webkitColumnWidth = workWidth + 'px';
        titel.style.columnWidth = workWidth + 'px';
	titel.style.height = viewHeight + 'px';

	var letztesTitelElement = letztesElement(titel);

	var screen = Math.floor((letztesTitelElement.offsetLeft  + letztesTitelElement.offsetWidth) / (workWidth + columnGap));
	var t = 0;
	if (letztesTitelElement.offsetTop + letztesTitelElement.offsetHeight > viewHeight) {
	  screen += 1;
	  t = letztesTitelElement.offsetHeight;
	} else
	  t = letztesTitelElement.offsetHeight + letztesTitelElement.offsetTop;

	left = screen * (workWidth + columnGap);

	var offset = Math.round(t % EPUBTAZ.lineHight);
	if (offset != 0) offset = Math.round(EPUBTAZ.lineHight) - offset;
	colTop = t + offset;

      } else {
	var offset = Math.round(titel.offsetHeight % EPUBTAZ.lineHight);
	if (offset != 0) offset = Math.round(EPUBTAZ.lineHight) - offset;
	colTop = titel.offsetHeight + offset;
      }
      offset = Math.round(viewHeight % EPUBTAZ.lineHight);
      if (offset != 0) viewHeight = viewHeight - offset;

      colHeight = viewHeight - colTop;
      if (nCols > 1) {
	colWidth = (workWidth - ((nCols - 1) * columnGap)) / nCols;
      }

      preCheckContent(content, workWidth);

      // colHeight = Math.ceil(Math.floor(colHeight / EPUBTAZ.lineHight) * EPUBTAZ.lineHight); Leider nicht im Register

      if (brot) {
	renderRegion(colTop);
      } else 
	renderRest();
      setPagePos(params.wordPos);
      pageSetup.pageReady();
    }
  }

  function checkWordSpan(node) {
    // return node.nodeType == 1 && node.nodeName == 'SPAN' && node.getAttribute ("data-wc");
    return (node.nodeType == 1 || node.nodeType == 3) && node.childElementCount == 0;
  }

  function letztesElement(node) {
    if (node.hasChildNodes()) {
      for (var i=node.childNodes.length - 1; i >= 0; i--) {
	var ln = node.childNodes[i];
	if (ln.nodeType == 1) {
	  return letztesElement(ln);
	}
      }
    }
    return node;
  }

  return (function() {

    /**
     * init
     *
     * Initalisiert das Objekt 
     */
    function init (params) {
      EPUBTAZ.log("regionPager.init: contentId=", params.contentId, " titelId=", params.titleId, " brotId=", params.brotId, " fotoId=", params.fotoId);
      TAZAPI.enableRegionScroll(true);
      content = document.getElementById(params.contentId);
      titel   = document.getElementById(params.titleId);
      brot    = document.getElementById(params.brotId);
      foto    = document.getElementById(params.fotoId);

      if (foto) foto.style.display = 'block';
      if (content) {
        content.classList.add('noScroll');
	if (EPUBTAZ.isJustify) content.classList.add('isJustify');
      }

      var headID = document.getElementsByTagName("head")[0];         
      var style = document.createElement("link");
      style.setAttribute('type','text/css');
      style.rel   = 'stylesheet';
      style.href  = TAZAPI.resourcePathPrefix+'res/css/column.css';
      style.media = 'screen';
      headID.appendChild(style);

      window.onscroll = regionPager.scrollHandler;

      if (TAZAPI.windowInfo)
        EPUBTAZ.log("regionPager:init has windowInfo");
      else
        EPUBTAZ.log("regionPager:init no windowInfo");
    }

    // return public interface
    return {
      get percentSeen()		{ return percentSeen; },
      get numberOfPages()	{ return numberOfPages; },
      get currentPos()		{ return currentPos; },
      get currentPage()		{ return page; },

      scrollHandler	: scrollHandler,
      pageLeft		: pageLeft,
      pageRight		: pageRight,
      lastPage		: lastPage,
      leftTab		: leftTab,
      rightTab		: rightTab,
      render		: render,
      getPagePos	: getPagePos,
      init		: init
    }
  } ());
}());
