/*
 *  JS functions for taz bookmarks in iOS
 */

/* Defines class name of element with id */
function setClass(clname, id = "content") {
  var elem = document.getElementById(id);
  elem.classname = mode;
}

/* Define padding of CSS selector */
function setPadding(padding, selector = "body") {
  var sel = document.querySelector(selector);
  sel.style.padding = wpadding;
}

/* Define font size of CSS selector */
function setFontSize(val, selector = "html") {
  var sel = document.querySelector(selector);
  sel.style.fontSize = val;
}

/* Define text alignment of CSS selector */
function setTextAlign(val, selector = "p") {
  var sel = document.querySelector(selector);
  sel.style.textAlign = val;
}

/* Shrink article to height 0 */
function shrink(art) {
  var currentHeight = art.scrollHeight;
  var trans = art.style.transition;
  art.style.transition = "";
  requestAnimationFrame(() => {
    art.style.height = currentHeight + "px";
    art.style.transition = trans;
    requestAnimationFrame(() => {
      art.style.height = "0px";
    });
  });
}

/* Delete bookmark */
function deleteBookmark(elem) {
  const art = elem.parentElement.parentElement.parentElement;
  art.addEventListener("transitionend", (e) => {
    art.remove();
    tazApi.setBookmark(art.id + ".html", false);
  });
  shrink(art);
}

/* Share Article */
function shareArticle(elem) {
  const art = elem.parentElement.parentElement.parentElement;
  tazApi.shareArticle(art.id + ".html");
}

/* Set up click functions for share and trash icons */
function setupButtons() {
  for (var b of document.getElementsByClassName("trash")) {
    b.addEventListener("click", (event) => {
      event.preventDefault();
      deleteBookmark(event.target);
    });
  }
  for (var b of document.getElementsByClassName("share")) {
    b.addEventListener("click", (event) => {
      event.preventDefault();
      shareArticle(event.target);
    });
  }
}

/* Read settings from localStorage */
function readSettings() {
  var val = localStorage.getItem("tazApi.colorTheme");
  if (val) { setClass(val); }
  if (val = localStorage.getItem("tazApi.padding"))
    { setPadding(val); }
  if (val = localStorage.getItem("tazApi.fontSize"))
    { setFontSize(val); }
  if (val = localStorage.getItem("tazApi.textAlign"))
    { setTextAlign(val); }
}

/* Functions used from the native side */ 

/* Set the color theme to use, either "light" or "dark" */
tazApi.setColorTheme = (theme) => {
  localStorage.setItem("tazApi.colorTheme", theme);
  setClass(theme);
}

/* Set padding of body, eg. "10px 15px 20px 30px" */
tazApi.setPadding = (padding) => {
  localStorage.setItem("tazApi.padding", padding);
  setPadding(padding);
}

/* Set font-size of html element (define root em) */
tazApi.setFontSize = (fsize) => {
  localStorage.setItem("tazApi.fontSize", fsize);
  setFontSize(fsize);
}

/* Set text alignment of p elements */
tazApi.setTextAlign = (alignment) => {
  localStorage.setItem("tazApi.textAlign", alignment);
  setTextAlign(alignment);
}

/* Indicates that we can handle CSS change requests */
tazApi.hasDynamicCSS = () => { return true; }

/* Initialize CSS and setup buttons when DOM is ready */
document.addEventListener("DOMContentLoaded", (e) => {
  readSettings();
  setupButtons();
});
