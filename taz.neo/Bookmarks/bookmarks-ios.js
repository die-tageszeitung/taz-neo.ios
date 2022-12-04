/*
 *  JS functions for taz bookmarks in iOS
 */

/* Set color theme class of element to either "dark" or "light" */
function setColorTheme(theme, selector = "body") {
  let elems = document.querySelectorAll(selector);
  if (elems) {
    for (let elem of elems) {
      if (theme == "dark") {
        elem.classList.remove("light");
        elem.classList.add("dark");
      }
      else {
        elem.classList.remove("dark");
        elem.classList.add("light");
      }
    }
  }
  if (selector == "body") {
    setColorTheme(theme, "a:link, a:visited, a:hover, a:active, a:focus");
    setColorTheme(theme, "article");
    setColorTheme(theme, "header");
  }
}

/* Adjust photo sizes */
function adjustPhotoSize(factor) {
  const newSize = 65.0 * factor;
  let elems = document.querySelectorAll(".photo");
  if (elems) {
    for (let elem of elems) {
      elem.style.width = newSize + "px";
      elem.style.height = newSize + "px";
    }
  }
}

/* Adjust horizontal padding of "#content" */
function adjustPadding(percent) {
  let horPadding = 15;
  const windowWidth = parseFloat(window.innerWidth);
  const windowHeight = parseFloat(window.innerHeight);
  const isLandscape = Math.abs(window.orientation) == 90;
  let width, maxwidth;
  if (isLandscape) { width = Math.max(windowWidth, windowHeight); }
  else { width = Math.min(windowWidth, windowHeight); }
  let columnWidth;
  if (width > 600) {
    const basewidth = isLandscape ? 600.0 * 1.32 : 600.0;
    columnWidth = Math.min(basewidth * (percent/100.0), width - 30.0);
  }
  else { columnWidth = width - 30.0; }
  horPadding = (width - columnWidth) / 2.0;
  let sel = document.querySelector("#content");
  if (sel) {
    sel.style.paddingRight = horPadding + "px";
    sel.style.paddingLeft = horPadding + "px";
  }
  adjustPhotoSize(columnWidth/390.0);
}

/* 
 * Define Size of Article column in percent of viewport width if and only if
 * the media size is larger than 600px
 */
function setColumnSize(percent) {
  let pc = parseFloat(percent);
  adjustPadding(pc);
  window.addEventListener("orientationchange", () => {
    adjustPadding(pc);
  })
}

/* Define font size of CSS selector in percent of default font size */
function setFontSize(percent, selector = "html") {
  let sel = document.querySelector(selector);
  if (sel) {
    let pxsize = 17.0 * (parseFloat(percent)/100.0);
    sel.style.fontSize = pxsize + "px";
  }
}

/* Define text alignment of CSS selector */
function setTextAlign(val, selector = "p") {
  let sel = document.querySelector(selector);
  if (sel) { sel.style.textAlign = val; }
}

/* Shrink article to height 0 */
function shrink(art) {
  let currentHeight = art.scrollHeight;
  let trans = art.style.transition;
  art.style.transition = "";
  requestAnimationFrame(() => {
    art.style.height = currentHeight + "px";
    art.style.transition = trans;
    requestAnimationFrame(() => {
      art.style.height = "0px";
    });
  });
}

function resetArticleHeight(event) {
  let art = event.target;
  art.style.height = "auto";  
  art.removeEventListener("transitionend", resetArticleHeight);
}

/* Grow article to its scrollHeight (ie. the size needed to display it) */
function grow(art) {
  art.addEventListener("transitionend", resetArticleHeight);
  let sheight = art.scrollHeight;
  let trans = art.style.transition;
  art.style.transition = "";
  requestAnimationFrame(() => {
    art.style.height = "0px";
    art.style.transition = trans;
    requestAnimationFrame(() => {
      art.style.height = sheight + "px";
    });
  });
}

function reallyDeleteBookmark(event) {
  let art = event.target;
  const title = art.querySelector("h2").textContent;
  tazApi.toast("<h3>" + title + "</h3>" + "Löschen rückgängig durch Antippen",
    3.0, (wasTapped) => {
    if (wasTapped) {
      let rect = art.getBoundingClientRect();
      if (rect.height <= 2) { grow(art); }
    }
    else {
      art.remove();
      tazApi.setBookmark(art.id + ".html", false);
    }
  });
  art.removeEventListener("transitionend", reallyDeleteBookmark);
}

/* Delete bookmark */
function deleteBookmark(elem) {
  const art = elem.parentElement.parentElement.parentElement;
  art.addEventListener("transitionend", reallyDeleteBookmark);
  shrink(art);
}

function insertArticle(html, id, order) {
  let art = docment.createElement("article");
  art.id = id;
  art.innerHTML = html;
  art.style.height = "0px";
  art.style.order = order;
  let content = document.getElementById("content");
  content.appendChild(art);
  grow(art);
}

/* Share Article */
function shareArticle(elem) {
  const art = elem.parentElement.parentElement.parentElement;
  tazApi.shareArticle(art.id + ".html");
}

/* Set up click functions for share and bookmark icons */
function setupButtons() {
  for (let b of document.getElementsByClassName("bookmark")) {
    b.addEventListener("click", (event) => {
      event.preventDefault();
      deleteBookmark(event.target);
    });
  }
  for (let b of document.getElementsByClassName("share")) {
    b.addEventListener("click", (event) => {
      event.preventDefault();
      shareArticle(event.target);
    });
  }
}

/* Functions used from the native side */ 

/* Set the color theme to use, either "light" or "dark" */
tazApi.setColorTheme = (theme) => {
  setColorTheme(theme);
}

/* Set column size of #content if window width > 600px */
tazApi.setColumnSize = (percent) => {
  setColumnSize(percent);
}

/* Set font-size of html element (define root em) in percent of 17px */
tazApi.setFontSize = (fsize) => {
  setFontSize(fsize);
}

/* Set text alignment of p elements */
tazApi.setTextAlign = (alignment) => {
  setTextAlign(alignment);
}

/* Indicates that we can handle CSS change requests */
tazApi.hasDynamicStyles = () => { return true; }

/* Initialize CSS and setup buttons when DOM is ready */
document.addEventListener("DOMContentLoaded", (e) => {
  tazApi.setDynamicStyles();
  setupButtons();
});
